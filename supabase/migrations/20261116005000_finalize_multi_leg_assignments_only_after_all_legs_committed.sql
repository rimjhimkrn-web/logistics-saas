-- For an active multi-leg route, finalise each accepted partner assignment
-- independently. Keep the shipment in confirmed state until every plan leg has
-- an active/completed assignment and a committed capacity commitment.
DO $migration$
DECLARE
  v_def text;
  v_old_decl text := $decl_old$  v_opportunity public.krim_partner_opportunities%rowtype;
begin$decl_old$;
  v_new_decl text := $decl_new$  v_opportunity public.krim_partner_opportunities%rowtype;
  v_plan public.krim_shipment_leg_plans%rowtype;
  v_required_legs integer;
  v_ready_legs integer;
begin$decl_new$;
  v_old_body text := $body_old$  if v_commitment.partner_organization_id <> v_assignment.partner_organization_id then
    raise exception 'Capacity commitment partner does not match assignment partner';
  end if;

  select * into v_opportunity$body_old$;
  v_new_body text := $body_new$  if v_commitment.partner_organization_id <> v_assignment.partner_organization_id then
    raise exception 'Capacity commitment partner does not match assignment partner';
  end if;

  select * into v_plan
  from public.krim_shipment_leg_plans
  where shipment_id=v_assignment.shipment_id
    and status='active'
    and total_legs>1
  order by plan_version desc
  limit 1
  for update;

  if found then
    if v_assignment.shipment_leg_id is null then
      raise exception 'Multi-leg assignment % is not bound to an exact shipment leg',v_assignment.id;
    end if;

    update public.krim_shipment_partner_assignments
    set status='active',accepted_at=coalesce(accepted_at,now()),updated_at=now()
    where id=v_assignment.id
    returning * into v_assignment;

    update public.krim_shipment_legs
    set partner_organization_id=v_assignment.partner_organization_id,
        assignment_status='active',
        status='assigned',
        updated_at=now()
    where id=v_assignment.shipment_leg_id
      and shipment_id=v_assignment.shipment_id;

    if not found then
      raise exception 'Multi-leg assignment % references a missing shipment leg',v_assignment.id;
    end if;

    select count(*)::integer into v_required_legs
    from public.krim_shipment_leg_plan_items
    where plan_id=v_plan.id;

    if v_required_legs<>v_plan.total_legs then
      raise exception 'Active route plan % has an inconsistent leg count',v_plan.id;
    end if;

    select count(distinct pi.id)::integer into v_ready_legs
    from public.krim_shipment_leg_plan_items pi
    join public.krim_shipment_legs l
      on l.leg_plan_item_id=pi.id
     and l.shipment_id=v_assignment.shipment_id
    join public.krim_shipment_partner_assignments a
      on a.shipment_leg_id=l.id
     and a.shipment_id=l.shipment_id
     and a.partner_organization_id=l.partner_organization_id
     and a.status in ('active','completed')
    join public.krim_partner_shipment_capacity_commitments c
      on c.assignment_id=a.id
     and c.partner_organization_id=a.partner_organization_id
     and c.status='committed'
    where pi.plan_id=v_plan.id;

    if v_ready_legs=v_required_legs then
      update public.krim_shipments
      set status='assigned',updated_at=now()
      where id=v_shipment.id;

      insert into public.krim_audit_events
        (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
      values
        (null,v_shipment.customer_organization_id,'shipment.partner_assigned','shipment',v_shipment.id::text,'partner_network',
         jsonb_build_object('multi_leg_plan_id',v_plan.id,'assigned_legs',v_ready_legs,'required_legs',v_required_legs),
         jsonb_build_object('status','confirmed'),jsonb_build_object('status','assigned'),now());

      return jsonb_build_object('assigned',true,'partial',false,'multi_leg',true,
        'shipment_id',v_shipment.id,'shipment_number',v_shipment.shipment_number,
        'status','assigned','assigned_legs',v_ready_legs,'required_legs',v_required_legs,
        'next_step','dispatch_first_ready_leg');
    end if;

    insert into public.krim_audit_events
      (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
    values
      (null,v_shipment.customer_organization_id,'shipment.partner_leg_assigned','shipment_leg',v_assignment.shipment_leg_id::text,'partner_network',
       jsonb_build_object('assignment_id',v_assignment.id,'multi_leg_plan_id',v_plan.id,
         'assigned_legs',v_ready_legs,'required_legs',v_required_legs),
       jsonb_build_object('assignment_status','accepted'),jsonb_build_object('assignment_status','active'),now());

    return jsonb_build_object('assigned',false,'partial',true,'multi_leg',true,
      'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,
      'status',v_shipment.status,'assigned_legs',v_ready_legs,'required_legs',v_required_legs,
      'next_step','source_and_confirm_remaining_legs');
  end if;

  select * into v_opportunity$body_new$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef(
    'public.krim_internal_finalize_partner_assignment(bigint)'::regprocedure
  ) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old_decl)=0 THEN
    RAISE EXCEPTION 'Expected partner assignment finalizer declaration anchor not found';
  END IF;
  v_def:=pg_catalog.replace(v_def,v_old_decl,v_new_decl);
  IF pg_catalog.strpos(v_def,v_old_body)=0 THEN
    RAISE EXCEPTION 'Expected partner assignment finalizer capacity validation anchor not found';
  END IF;
  v_def:=pg_catalog.replace(v_def,v_old_body,v_new_body);
  EXECUTE v_def;
END
$migration$;
