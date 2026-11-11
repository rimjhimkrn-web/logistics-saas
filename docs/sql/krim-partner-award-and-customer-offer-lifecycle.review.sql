-- REVIEW-ONLY coordinated lifecycle correction. Not deployed.
-- Target sequence:
-- customer selects a partner quote -> offered assignment + shortlisted opportunity
-- partner accepts -> assignment accepted + capacity commitment + award finalised
-- partner schedules capacity -> confirmed binding + reservation
-- customer accepts presented/sent offer -> customer quote accepted
-- payment may then be initiated by the existing guarded payment workflow.
--
-- This patch deliberately does not transition shipment to confirmed when a
-- customer merely selects a partner quote. It does not create an accepted
-- customer quote or accepted quote version during partner award.
--
-- Pre-requisites:
-- 1. Apply and validate the separate customer quote acceptance capacity guard.
-- 2. Validate all function callers and grants in staging.
-- 3. Reconcile historical accepted quotes/assignments before rollout.
-- 4. Test partner rejection, retries, capacity release and concurrent awards.

create or replace function public.krim_award_partner_quote(p_partner_quote_id bigint)
returns public.krim_shipment_partner_assignments
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_assignment_number text;
  v_leg_id bigint;
begin
  if v_user_id is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if p_partner_quote_id is null or p_partner_quote_id <= 0 then
    raise exception using errcode='22023', message='A valid partner quote is required';
  end if;

  select * into v_quote
  from public.krim_partner_quotes
  where id=p_partner_quote_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Partner quote not found';
  end if;

  select * into v_opportunity
  from public.krim_partner_opportunities
  where id=v_quote.opportunity_id
  for update;
  if not found or not private.krim_has_organization_access(v_user_id,v_opportunity.customer_organization_id) then
    raise exception using errcode='42501', message='Opportunity is not accessible to this organization';
  end if;
  if not private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'quote.update')
     or not private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'shipment.update') then
    raise exception using errcode='42501', message='Permission denied: quote award requires quote.update and shipment.update';
  end if;

  if exists (
    select 1 from public.krim_organizations o
    where o.id=v_quote.partner_organization_id
      and coalesce(o.partner_account_mode,'')='development_test'
  ) then
    raise exception using errcode='42501', message='Development/test partners cannot be awarded commercial shipments';
  end if;

  select * into v_assignment
  from public.krim_shipment_partner_assignments
  where partner_quote_id=p_partner_quote_id
  order by created_at desc
  limit 1
  for update;
  if v_assignment.id is not null then
    return v_assignment;
  end if;

  if v_opportunity.status<>'open'
     or v_opportunity.awarded_partner_organization_id is not null
     or (v_opportunity.response_deadline is not null and v_opportunity.response_deadline<=now()) then
    raise exception using errcode='22023', message='Opportunity is no longer open for award';
  end if;
  if v_quote.status not in ('submitted','under_review','shortlisted')
     or (v_quote.valid_until is not null and v_quote.valid_until<=now()) then
    raise exception using errcode='22023', message='Partner quote is not eligible for award';
  end if;

  if not exists (
    select 1 from public.krim_organizations o
    where o.id=v_quote.partner_organization_id
      and o.status='active'
      and o.organization_type in ('partner','carrier','forwarder')
      and o.partner_account_mode='registered_business'
      and exists (
        select 1 from public.krim_partner_capabilities pc
        where pc.organization_id=o.id and pc.active is true
          and pc.verification_status='verified'
          and (pc.effective_from is null or pc.effective_from<=now())
          and (pc.effective_until is null or pc.effective_until>now())
      )
      and o.partner_verification_status in ('verified','approved')
      and o.partner_lifecycle_status in ('active','verified')
      and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
  ) then
    raise exception using errcode='42501', message='The bidding partner is no longer eligible for assignment';
  end if;

  select * into v_shipment
  from public.krim_shipments
  where id=v_quote.shipment_id
  for update;
  if not found or v_shipment.customer_organization_id<>v_opportunity.customer_organization_id
     or v_opportunity.shipment_id<>v_shipment.id then
    raise exception using errcode='23503', message='Partner quote shipment does not match the opportunity';
  end if;
  if not private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) then
    raise exception using errcode='42501', message='Partner capability no longer covers the shipment route, transport mode or weight';
  end if;

  select id into v_leg_id
  from public.krim_shipment_legs
  where shipment_id=v_shipment.id
  order by leg_sequence asc
  limit 1;

  -- Do not mark partner quote accepted or reject competitors until partner
  -- explicitly accepts the offered assignment.
  update public.krim_partner_opportunities
  set status='shortlisted', updated_at=now()
  where id=v_opportunity.id;

  v_assignment_number := 'KPA-' || to_char(now(),'YYYYMMDD') || '-' ||
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.krim_shipment_partner_assignments (
    shipment_id,shipment_leg_id,partner_organization_id,partner_quote_id,
    assignment_number,status,offered_at,response_deadline,assigned_by,metadata
  ) values (
    v_shipment.id,v_leg_id,v_quote.partner_organization_id,v_quote.id,
    v_assignment_number,'offered',now(),now()+interval '24 hours',v_user_id,
    jsonb_build_object('source','customer_partner_quote_selection','opportunity_id',v_opportunity.id)
  )
  returning * into v_assignment;

  insert into public.krim_audit_events (
    actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata
  ) values (
    v_user_id,v_opportunity.customer_organization_id,'partner.quote.shortlisted',
    'partner_quote',v_quote.id::text,'customer_partner_quote_selection',
    jsonb_build_object('opportunity_id',v_opportunity.id,'assignment_id',v_assignment.id,
      'partner_organization_id',v_quote.partner_organization_id)
  );

  return v_assignment;
end;
$function$;

-- Once the partner has accepted, the existing capacity-commitment trigger
-- must run first. PostgreSQL orders same-timing triggers alphabetically by name;
-- the z-prefixed trigger below deliberately runs after the existing
-- trg_krim_ensure_assignment_capacity_commitment trigger. Any failure rolls
-- back the entire assignment acceptance transaction.
create or replace function private.krim_finalize_partner_award_after_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
begin
  if old.status is distinct from 'offered' or new.status is distinct from 'accepted' then
    return new;
  end if;
  if new.partner_quote_id is null then
    raise exception using errcode='23514', message='Accepted assignment requires a linked partner quote';
  end if;

  select * into v_quote
  from public.krim_partner_quotes
  where id=new.partner_quote_id
    and shipment_id=new.shipment_id
    and partner_organization_id=new.partner_organization_id
  for update;
  if not found then
    raise exception using errcode='23514', message='Accepted assignment partner quote linkage is invalid';
  end if;

  select * into v_opportunity
  from public.krim_partner_opportunities
  where id=v_quote.opportunity_id
    and shipment_id=new.shipment_id
  for update;
  if not found or v_opportunity.status not in ('open','shortlisted') then
    raise exception using errcode='23514', message='Partner opportunity is not eligible to be awarded';
  end if;

  update public.krim_partner_quotes
  set status='accepted',accepted_at=coalesce(accepted_at,now()),updated_at=now()
  where id=v_quote.id;

  update public.krim_partner_quotes
  set status='rejected',rejected_at=coalesce(rejected_at,now()),updated_at=now()
  where opportunity_id=v_opportunity.id
    and id<>v_quote.id
    and status in ('submitted','under_review','shortlisted');

  update public.krim_partner_opportunities
  set status='awarded',awarded_partner_organization_id=new.partner_organization_id,
      awarded_at=coalesce(awarded_at,now()),updated_at=now()
  where id=v_opportunity.id;

  return new;
end;
$function$;

drop trigger if exists trg_krim_z_finalize_partner_award_after_acceptance
  on public.krim_shipment_partner_assignments;

create trigger trg_krim_z_finalize_partner_award_after_acceptance
after update of status on public.krim_shipment_partner_assignments
for each row
when (old.status='offered' and new.status='accepted')
execute function private.krim_finalize_partner_award_after_acceptance();

revoke all on function private.krim_finalize_partner_award_after_acceptance()
  from public,anon,authenticated,service_role;

-- Customer-facing quote creation: create a SENT offer, not an accepted quote.
-- Partner must have accepted the assignment first; customer acceptance is a
-- separate action and is guarded by the capacity-confirmation trigger.
create or replace function public.krim_award_partner_quote_for_checkout(
  p_partner_quote_id bigint,
  p_valid_until timestamptz default (now()+interval '7 days')
)
returns public.krim_quotes
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_partner_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_assignment public.krim_shipment_partner_assignments%rowtype;
  v_customer_quote public.krim_quotes%rowtype;
  v_existing_quote public.krim_quotes%rowtype;
  v_version_id bigint;
  v_version_number integer;
  v_valid_until timestamptz := p_valid_until;
begin
  if v_user_id is null then
    raise exception using errcode='28000',message='Authentication required';
  end if;
  if p_partner_quote_id is null or p_partner_quote_id<=0 then
    raise exception using errcode='22023',message='A valid partner quote is required';
  end if;

  select * into v_partner_quote from public.krim_partner_quotes
  where id=p_partner_quote_id for update;
  if not found then raise exception using errcode='P0002',message='Partner quote not found'; end if;

  select * into v_opportunity from public.krim_partner_opportunities
  where id=v_partner_quote.opportunity_id for update;
  if not found then raise exception using errcode='P0002',message='Partner opportunity not found'; end if;

  if not private.krim_has_organization_access(v_user_id,v_opportunity.customer_organization_id) then
    raise exception using errcode='42501',message='Opportunity is not accessible to this customer organization';
  end if;
  if not private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'quote.update')
     or not private.krim_has_permission(v_user_id,v_opportunity.customer_organization_id,'shipment.update') then
    raise exception using errcode='42501',message='Permission denied: quote award requires quote.update and shipment.update';
  end if;

  select * into v_existing_quote from public.krim_quotes
  where partner_quote_id=p_partner_quote_id for update;
  if found then
    if v_existing_quote.status in ('sent','accepted') then
      return v_existing_quote;
    end if;
    raise exception using errcode='22023',message='A customer offer already exists for this partner quote';
  end if;

  if v_partner_quote.status<>'accepted' then
    raise exception using errcode='22023',message='Partner must accept the assignment before a customer offer is issued';
  end if;
  if v_opportunity.status<>'awarded'
     or v_opportunity.awarded_partner_organization_id is distinct from v_partner_quote.partner_organization_id then
    raise exception using errcode='22023',message='Partner award is not finalised';
  end if;

  select * into v_shipment from public.krim_shipments
  where id=v_partner_quote.shipment_id for update;
  if not found or v_shipment.customer_organization_id<>v_opportunity.customer_organization_id
     or v_opportunity.shipment_id<>v_shipment.id then
    raise exception using errcode='42501',message='Partner quote does not match the authorized customer shipment';
  end if;
  if v_shipment.status not in ('quoted','confirmed') then
    raise exception using errcode='22023',message='Shipment is not in an offerable state';
  end if;
  if v_partner_quote.amount<=0 then
    raise exception using errcode='22023',message='Partner quote amount must be greater than zero';
  end if;

  if v_valid_until is null or v_valid_until<=now()+interval '1 hour'
     or v_valid_until>now()+interval '30 days' then
    raise exception using errcode='22023',message='Customer quote validity must be between one hour and 30 days';
  end if;
  if v_partner_quote.valid_until is not null then
    v_valid_until:=least(v_valid_until,v_partner_quote.valid_until);
  end if;
  if v_valid_until<=now()+interval '1 hour' then
    raise exception using errcode='22023',message='Partner quote expires too soon to create a customer offer';
  end if;

  select * into v_assignment from public.krim_shipment_partner_assignments
  where partner_quote_id=p_partner_quote_id
    and shipment_id=v_shipment.id
    and partner_organization_id=v_partner_quote.partner_organization_id
  order by created_at desc limit 1 for update;
  if not found or v_assignment.status<>'accepted' then
    raise exception using errcode='22023',message='Accepted partner assignment is required';
  end if;

  if exists (
    select 1 from public.krim_quotes q
    where q.shipment_id=v_shipment.id and q.status in ('draft','sent','accepted')
  ) then
    raise exception using errcode='23505',message='An active customer quote already exists for this shipment';
  end if;

  insert into public.krim_quotes (
    shipment_id,customer_organization_id,amount,currency_code,
    valid_until,status,partner_quote_id,pricing_snapshot
  ) values (
    v_shipment.id,v_opportunity.customer_organization_id,v_partner_quote.amount,
    v_partner_quote.currency_code,v_valid_until,'sent',v_partner_quote.id,
    jsonb_build_object('source','partner_quote_offer','partner_quote_id',v_partner_quote.id,
      'partner_organization_id',v_partner_quote.partner_organization_id,
      'tax_breakdown_status','not_separately_calculated','customer_acceptance_required',true)
  )
  returning * into v_customer_quote;

  select coalesce(max(version_number),0)+1 into v_version_number
  from public.krim_quote_versions where quote_id=v_customer_quote.id;

  insert into public.krim_quote_versions (
    quote_id,version_number,status,currency_code,subtotal,tax_amount,total_amount,
    valid_from,valid_until,customer_terms,pricing_snapshot,created_by
  ) values (
    v_customer_quote.id,v_version_number,'presented',v_partner_quote.currency_code,
    v_partner_quote.amount,0,v_partner_quote.amount,now(),v_valid_until,
    jsonb_build_object('payment_terms','payment only after customer acceptance and payment verification',
      'tax_breakdown_status','not_separately_calculated','production_tax_invoice_ready',false),
    jsonb_build_object('source','accepted_partner_quote','partner_quote_id',v_partner_quote.id,
      'partner_organization_id',v_partner_quote.partner_organization_id,
      'opportunity_id',v_opportunity.id,'assignment_id',v_assignment.id,
      'total_customer_payable',v_partner_quote.amount,'currency_code',v_partner_quote.currency_code,
      'finance_reconciliation_required',true),
    v_user_id
  ) returning id into v_version_id;

  insert into public.krim_quote_events (
    quote_id,version_id,event_type,previous_status,new_status,actor_user_id,event_time,payload
  ) values (
    v_customer_quote.id,v_version_id,'quote.sent_from_partner_award',null,'sent',
    v_user_id,now(),jsonb_build_object('partner_quote_id',v_partner_quote.id,
      'assignment_id',v_assignment.id,'opportunity_id',v_opportunity.id,
      'amount',v_partner_quote.amount,'currency_code',v_partner_quote.currency_code)
  );

  return v_customer_quote;
end;
$function$;

-- Staging validation is mandatory:
-- 1. Customer selection creates offered assignment; quote stays shortlisted;
--    opportunity stays shortlisted; shipment is not confirmed.
-- 2. No competitor quote is rejected until selected partner accepts.
-- 3. Partner acceptance creates commitment and atomically accepts selected
--    partner quote, rejects competitors and awards opportunity.
-- 4. Partner rejection reopens opportunity and restores competitor eligibility.
-- 5. Checkout RPC before partner acceptance fails.
-- 6. After partner acceptance, checkout RPC creates customer quote status sent
--    and version presented; it never marks either accepted.
-- 7. Customer acceptance before confirmed capacity binding/reservation fails.
-- 8. After confirmed binding+reservation, customer acceptance succeeds.
-- 9. Duplicate calls, concurrent competing awards, expired quotes, revoked
--    partner compliance and transaction rollback are tested.
-- 10. Verify every quote/payment/booking RPC and client caller, including
--     krim_customer_accept_quote, krim_accept_global_quote and
--     krim_internal.accept_quote_and_commit, against the same invariants.
--
-- Rollback: restore the exact prior function definitions and drop the new
-- trigger/function. Do not use a generic rollback on production.
