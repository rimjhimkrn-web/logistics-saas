-- PROPOSED ONLY: reviewed draft; do not apply until migration-history reconciliation
-- and a disposable-database test run are complete.
-- Resolves user identities only. It deliberately does not read email/phone,
-- create outbox rows, or send messages.

create or replace function krim_internal.resolve_shipment_notification_recipients(
  p_shipment_id bigint,
  p_recipient_type text,
  p_intent_code text
)
returns table (
  recipient_type text,
  organization_id bigint,
  user_id uuid,
  member_role text,
  resolution_source text,
  preferred_language_code text,
  timezone text
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_shipment_id is null or p_shipment_id <= 0 then
    raise exception 'invalid_shipment_id' using errcode = '22023';
  end if;

  if p_recipient_type is null or p_recipient_type not in ('customer', 'partner') then
    raise exception 'unsupported_recipient_type' using errcode = '22023';
  end if;

  if p_intent_code is null or p_intent_code not in (
    'shipment.lifecycle.confirmed',
    'shipment.lifecycle.dispatched',
    'shipment.lifecycle.delivered',
    'shipment.lifecycle.exception',
    'shipment.lifecycle.assigned'
  ) then
    raise exception 'unsupported_notification_intent' using errcode = '22023';
  end if;

  if (p_recipient_type = 'customer' and p_intent_code not in (
        'shipment.lifecycle.confirmed','shipment.lifecycle.dispatched',
        'shipment.lifecycle.delivered','shipment.lifecycle.exception'))
     or (p_recipient_type = 'partner' and p_intent_code <> 'shipment.lifecycle.assigned') then
    raise exception 'notification_intent_recipient_mismatch' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.krim_shipments s
    where s.id = p_shipment_id
  ) then
    raise exception 'shipment_not_found' using errcode = 'P0002';
  end if;

  if p_recipient_type = 'customer' then
    return query
    select distinct
      'customer'::text,
      s.customer_organization_id,
      cil.user_id,
      m.role,
      'verified_customer_identity_and_active_membership'::text,
      coalesce(wp.preferred_language_code, cap.language_code),
      coalesce(wp.preferred_timezone, org.timezone)
    from public.krim_shipments s
    join public.krim_organizations org
      on org.id = s.customer_organization_id
     and org.status = 'active'
     and org.organization_type in ('customer', 'enterprise')
    join public.krim_customer_identity_links cil
      on cil.organization_id = org.id
     and cil.identity_status = 'verified'
     and cil.verified_at is not null
    join public.krim_customer_acquisition_profiles cap
      on cap.id = cil.customer_profile_id
     and (cap.organization_id is null or cap.organization_id = org.id)
     and cap.status = 'active'
    join public.krim_customer_workspace_profiles wp
      on wp.customer_profile_id = cap.id
     and wp.organization_id = org.id
     and wp.workspace_status = 'active'
     and wp.account_status = 'active'
    join public.krim_organization_members m
      on m.organization_id = org.id
     and m.user_id = cil.user_id
     and m.status = 'active'
     and m.role in ('owner','admin','operator','member')
    where s.id = p_shipment_id
      and s.customer_organization_id is not null
      and p_intent_code in ('shipment.lifecycle.confirmed','shipment.lifecycle.dispatched','shipment.lifecycle.delivered','shipment.lifecycle.exception');
    return;
  end if;

  return query
  select distinct
    'partner'::text,
    a.partner_organization_id,
    m.user_id,
    m.role,
    'active_shipment_assignment_and_verified_partner_membership'::text,
    null::text,
    org.timezone
  from public.krim_shipment_partner_assignments a
  join public.krim_organizations org
    on org.id = a.partner_organization_id
   and org.status = 'active'
   and org.organization_type in ('partner', 'carrier', 'warehouse', 'forwarder', 'customs')
   and org.partner_lifecycle_status = 'active'
   and org.partner_verification_status = 'verified'
   and org.partner_compliance_status = 'compliant'
  join public.krim_organization_members m
    on m.organization_id = org.id
   and m.status = 'active'
   and m.role in ('owner','admin','manager','dispatcher','operator')
  where a.shipment_id = p_shipment_id
    and a.status in ('offered', 'accepted', 'active')
    and p_intent_code = 'shipment.lifecycle.assigned';
end;
$function$;

revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from public;
revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from anon;
revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from authenticated;
grant execute on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) to service_role;

comment on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text)
is 'Internal identity-only resolver for shipment notification recipients with workflow-code role allowlists; service_role only; never sends messages.';


-- Maps only the five verified live shipment workflow/action pairs.
-- No default or inferred mapping is allowed.
create or replace function krim_internal.resolve_shipment_notification_intent(
  p_workflow_code text,
  p_action_type text
)
returns table (recipient_type text, intent_code text)
language plpgsql
immutable
set search_path = ''
as $function$
begin
  if p_workflow_code is null or p_action_type is null then
    raise exception 'workflow_notification_mapping_required' using errcode = '22023';
  end if;

  if p_workflow_code in (
       'shipment.lifecycle.confirmed',
       'shipment.lifecycle.dispatched',
       'shipment.lifecycle.delivered',
       'shipment.lifecycle.exception'
     )
     and p_action_type = 'prepare_customer_notification' then
    recipient_type := 'customer';
    intent_code := p_workflow_code;
    return next;
    return;
  end if;

  if p_workflow_code = 'shipment.lifecycle.assigned'
     and p_action_type = 'prepare_partner_notification' then
    recipient_type := 'partner';
    intent_code := 'shipment.lifecycle.assigned';
    return next;
    return;
  end if;

  raise exception 'unsupported_workflow_notification_mapping' using errcode = '22023';
end;
$function$;

revoke all on function krim_internal.resolve_shipment_notification_intent(text, text) from public;
revoke all on function krim_internal.resolve_shipment_notification_intent(text, text) from anon;
revoke all on function krim_internal.resolve_shipment_notification_intent(text, text) from authenticated;
grant execute on function krim_internal.resolve_shipment_notification_intent(text, text) to service_role;

comment on function krim_internal.resolve_shipment_notification_intent(text, text)
is 'Fail-closed mapping of verified shipment workflow/action pairs to recipient type and intent code; service_role only.';


-- Lease-fencing primitive for the future workflow executor/outbox handoff.
-- This helper is intentionally not wired into the live executor in this draft.
create or replace function krim_internal.assert_workflow_action_lease(
  p_action_execution_id bigint,
  p_lease_id uuid,
  p_worker_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_status text;
  v_lease_id uuid;
  v_lease_expires_at timestamptz;
  v_worker_id text;
begin
  if p_action_execution_id is null or p_lease_id is null
     or p_worker_id is null or btrim(p_worker_id) = '' then
    raise exception 'workflow_action_lease_arguments_required' using errcode = '22023';
  end if;

  select ae.status, ae.lease_id, ae.lease_expires_at,
         ae.request_snapshot->>'worker_id'
    into v_status, v_lease_id, v_lease_expires_at, v_worker_id
  from public.krim_workflow_action_executions ae
  where ae.id = p_action_execution_id
  for update;

  if not found then
    raise exception 'workflow_action_execution_not_found' using errcode = 'P0002';
  end if;

  if v_status <> 'running'
     or v_lease_id is distinct from p_lease_id
     or v_worker_id is distinct from p_worker_id
     or v_lease_expires_at is null
     or v_lease_expires_at <= clock_timestamp() then
    raise exception 'workflow_action_lease_stale_or_not_owned' using errcode = '55000';
  end if;
end;
$function$;

revoke all on function krim_internal.assert_workflow_action_lease(bigint,uuid,text) from public;
revoke all on function krim_internal.assert_workflow_action_lease(bigint,uuid,text) from anon;
revoke all on function krim_internal.assert_workflow_action_lease(bigint,uuid,text) from authenticated;
grant execute on function krim_internal.assert_workflow_action_lease(bigint,uuid,text) to service_role;

comment on function krim_internal.assert_workflow_action_lease(bigint,uuid,text)
is 'Locking lease ownership assertion for the future workflow action executor; not yet wired into the production batch path.';
