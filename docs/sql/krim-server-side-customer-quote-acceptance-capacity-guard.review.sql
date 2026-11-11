-- REVIEW-ONLY database guard. Do not run in production without staging tests,
-- migration review, rollback rehearsal and explicit release approval.
--
-- This trigger makes the customer quote acceptance invariant server-side.
-- It blocks accepted customer quotes unless the exact linked partner quote
-- has an accepted assignment and a confirmed capacity binding + reservation.
-- It also verifies customer/partner ownership across all linked records and
-- locks the reservation row to serialize acceptance against release/cancel.
-- It intentionally causes legacy award-for-checkout paths that create an
-- already-accepted quote before partner acceptance/capacity to fail closed.

create or replace function private.krim_guard_customer_quote_acceptance_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_assignment_id bigint;
  v_binding_id bigint;
  v_reservation_id bigint;
  v_partner_quote_id bigint;
  v_assignment_partner_org_id bigint;
  v_assignment_leg_id bigint;
  v_partner_quote_partner_org_id bigint;
  v_opportunity_customer_org_id bigint;
  v_shipment_customer_org_id bigint;
  v_binding_leg_id bigint;
  v_locked_reservation_id bigint;
begin
  if new.status is distinct from 'accepted' then
    return new;
  end if;

  if new.partner_quote_id is null then
    raise exception using
      errcode = '23514',
      message = 'Customer quote cannot be accepted without a linked partner quote';
  end if;

  -- Lock the assignment first, then the binding and reservation so concurrent
  -- cancellation/rejection cannot race customer acceptance.
  select a.id, a.capacity_binding_id, a.partner_quote_id,
         a.partner_organization_id, a.shipment_leg_id
    into v_assignment_id, v_binding_id, v_partner_quote_id,
         v_assignment_partner_org_id, v_assignment_leg_id
  from public.krim_shipment_partner_assignments a
  where a.shipment_id = new.shipment_id
    and a.partner_quote_id = new.partner_quote_id
  order by a.created_at desc
  limit 1
  for update;

  if v_assignment_id is null or v_partner_quote_id is distinct from new.partner_quote_id then
    raise exception using
      errcode = '23514',
      message = 'Customer quote requires a matching partner assignment';
  end if;

  -- Verify that the quote, opportunity, shipment and assignment all identify
  -- the same customer and partner; shipment_id alone is not sufficient.
  select pq.partner_organization_id, po.customer_organization_id
    into v_partner_quote_partner_org_id, v_opportunity_customer_org_id
  from public.krim_partner_quotes pq
  join public.krim_partner_opportunities po on po.id = pq.opportunity_id
  where pq.id = new.partner_quote_id
    and pq.shipment_id = new.shipment_id
  for key share of pq, po;

  select s.customer_organization_id
    into v_shipment_customer_org_id
  from public.krim_shipments s
  where s.id = new.shipment_id
  for key share;

  if v_partner_quote_partner_org_id is null
     or v_partner_quote_partner_org_id is distinct from v_assignment_partner_org_id
     or v_opportunity_customer_org_id is distinct from v_shipment_customer_org_id
     or new.customer_organization_id is distinct from v_shipment_customer_org_id then
    raise exception using
      errcode = '23514',
      message = 'Customer quote, partner quote, assignment and shipment ownership must match';
  end if;

  if not exists (
    select 1
    from public.krim_shipment_partner_assignments a
    where a.id = v_assignment_id
      and a.status = 'accepted'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Partner must explicitly accept the assignment before customer quote acceptance';
  end if;

  if v_binding_id is null then
    raise exception using
      errcode = '23514',
      message = 'Partner must confirm shipment-leg capacity before customer quote acceptance';
  end if;

  select b.reservation_id, b.shipment_leg_id
    into v_reservation_id, v_binding_leg_id
  from public.krim_capacity_leg_bindings b
  where b.id = v_binding_id
    and b.shipment_id = new.shipment_id
    and b.shipment_leg_id = v_assignment_leg_id
    and b.status = 'confirmed'
  for update;

  if v_reservation_id is null then
    raise exception using
      errcode = '23514',
      message = 'A confirmed capacity binding for this shipment is required';
  end if;

  -- Lock the reservation itself so a concurrent release/cancel cannot race
  -- the quote acceptance check.
  select r.id
    into v_locked_reservation_id
  from public.krim_capacity_reservations r
  where r.id = v_reservation_id
    and r.shipment_id = new.shipment_id
    and r.shipment_leg_id = v_binding_leg_id
    and r.organization_id = v_assignment_partner_org_id
    and r.status = 'confirmed'
  for update;

  if v_locked_reservation_id is null then
    raise exception using
      errcode = '23514',
      message = 'The linked capacity reservation must be confirmed';
  end if;

  return new;
end;
$function$;

revoke all on function private.krim_guard_customer_quote_acceptance_capacity()
  from public, anon, authenticated, service_role;

drop trigger if exists trg_krim_customer_quote_acceptance_capacity
  on public.krim_quotes;

create trigger trg_krim_customer_quote_acceptance_capacity
before insert or update of status, partner_quote_id, shipment_id
on public.krim_quotes
for each row
when (new.status = 'accepted')
execute function private.krim_guard_customer_quote_acceptance_capacity();

-- Staging test matrix (must run with fixture data and authenticated roles):
-- A. INSERT accepted quote with no partner_quote_id -> rejected.
-- B. INSERT/UPDATE accepted quote with offered assignment -> rejected.
-- C. accepted assignment but no capacity_binding_id -> rejected.
-- D. binding held/released or missing reservation -> rejected.
-- E. reservation held/cancelled/released -> rejected.
-- F. accepted assignment + confirmed binding + confirmed reservation,
--    all linked to same shipment/partner quote -> accepted.
-- G. wrong shipment, wrong partner_quote, cross-org actor -> rejected by
--    existing RPC authorization plus this linkage guard.
-- H. transition away from accepted remains allowed for cancellation/refund
--    workflows; transition into accepted always rechecks the invariant.
-- I. concurrent reservation release/rejection versus quote acceptance:
--    verify row-lock ordering and no accepted quote against released capacity.
-- J. existing historical accepted quotes: no backfill or automatic status
--    changes. Audit and reconcile those rows separately before deployment.

-- Rollback:
-- drop trigger if exists trg_krim_customer_quote_acceptance_capacity
--   on public.krim_quotes;
-- drop function if exists private.krim_guard_customer_quote_acceptance_capacity();
