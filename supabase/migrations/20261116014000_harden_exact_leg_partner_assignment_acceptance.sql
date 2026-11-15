DO $migration$
DECLARE
  v_def text;
  v_old text := $old$  select * into v_opportunity
  from public.krim_partner_opportunities
  where id=v_quote.opportunity_id;
  select * into v_shipment
  from public.krim_shipments
  where id=v_assignment.shipment_id
  for update;$old$;
  v_new text := $new$  select * into v_opportunity
  from public.krim_partner_opportunities
  where id=v_quote.opportunity_id;
  if p_accept and (
    v_quote.shipment_id is distinct from v_assignment.shipment_id
    or v_quote.partner_organization_id is distinct from v_assignment.partner_organization_id
  ) then
    raise exception using errcode='23514', message='Assignment quote must match its shipment and partner organisation';
  end if;
  if p_accept and exists (
    select 1 from public.krim_shipment_leg_plans p
    where p.shipment_id=v_assignment.shipment_id and p.status='active' and p.total_legs>1
  ) then
    if v_assignment.shipment_leg_id is null
       or v_quote.shipment_leg_id is distinct from v_assignment.shipment_leg_id
       or v_opportunity.shipment_id is distinct from v_assignment.shipment_id
       or v_opportunity.shipment_leg_id is distinct from v_assignment.shipment_leg_id
       or v_opportunity.status<>'awarded'
       or v_opportunity.awarded_partner_organization_id is distinct from v_assignment.partner_organization_id then
      raise exception using errcode='23514', message='Multi-leg assignment, quote and awarded opportunity must match the exact shipment leg and partner';
    end if;
    if not exists (
      select 1 from public.krim_shipment_legs l
      join public.krim_shipment_leg_plan_items pi on pi.id=l.leg_plan_item_id
      join public.krim_shipment_leg_plans p on p.id=pi.plan_id
      where l.id=v_assignment.shipment_leg_id and l.shipment_id=v_assignment.shipment_id
        and p.shipment_id=v_assignment.shipment_id and p.status='active'
        and pi.leg_sequence=l.leg_sequence
        and pi.origin_location_id is not distinct from l.origin_location_id
        and pi.destination_location_id is not distinct from l.destination_location_id
        and pi.transport_mode_id is not distinct from l.transport_mode_id
        and l.status in ('planned','unassigned')
        and l.assignment_status in ('unassigned','planned','pending')
    ) then
      raise exception using errcode='55000', message='Exact shipment leg is no longer an unassigned leg in the active route plan';
    end if;
  elsif p_accept and v_quote.shipment_leg_id is not null then
    if v_assignment.shipment_leg_id is distinct from v_quote.shipment_leg_id
       or v_opportunity.shipment_id is distinct from v_assignment.shipment_id
       or v_opportunity.shipment_leg_id is distinct from v_assignment.shipment_leg_id
       or v_opportunity.status<>'awarded'
       or v_opportunity.awarded_partner_organization_id is distinct from v_assignment.partner_organization_id then
      raise exception using errcode='23514', message='Leg-scoped assignment, quote and opportunity bindings do not match';
    end if;
  end if;
  select * into v_shipment
  from public.krim_shipments
  where id=v_assignment.shipment_id
  for update;$new$;
  v_old_org text := $oldorg$    if not private.krim_partner_compliance_is_current(v_assignment.partner_organization_id) then
      raise exception using errcode='42501', message='Partner verification or compliance is no longer active';
    end if;$oldorg$;
  v_new_org text := $neworg$    if not exists (
      select 1 from public.krim_organizations o
      where o.id=v_assignment.partner_organization_id and o.status='active'
        and lower(coalesce(o.organization_type_code,o.organization_type)) in ('partner','carrier','forwarder','logistics_provider')
        and o.partner_account_mode='registered_business'
        and o.partner_verification_status in ('verified','approved')
        and o.partner_lifecycle_status in ('active','verified')
        and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
    ) then
      raise exception using errcode='42501', message='Only currently verified registered-business partners may accept commercial assignments';
    end if;
    if not private.krim_partner_compliance_is_current(v_assignment.partner_organization_id) then
      raise exception using errcode='42501', message='Partner verification or compliance is no longer active';
    end if;$neworg$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'Expected partner acceptance linkage block not found'; END IF;
  v_def:=pg_catalog.replace(v_def,v_old,v_new);
  IF pg_catalog.strpos(v_def,v_old_org)=0 THEN RAISE EXCEPTION 'Expected partner compliance acceptance block not found'; END IF;
  v_def:=pg_catalog.replace(v_def,v_old_org,v_new_org);
  EXECUTE v_def;
END
$migration$;
