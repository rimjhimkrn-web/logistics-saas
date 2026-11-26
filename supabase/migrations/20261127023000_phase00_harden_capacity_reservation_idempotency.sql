-- Phase 00: fail closed on conflicting retries and cross-assignment capacity reuse.
DO $migration$
DECLARE
  v_definition text;
  v_expected_md5 constant text := '0cfaabd087247b4a80724b83edc809c5';
  v_old_binding text := $old$
 if found and v_binding.status in ('held','confirmed') and v_binding.reservation_id is not null and exists(select 1 from public.krim_capacity_reservations cr where cr.id=v_binding.reservation_id and cr.status in ('held','confirmed')) then
  update public.krim_shipment_partner_assignments set capacity_binding_id=v_binding.id,updated_at=now()
   where id=v_assignment.id and capacity_binding_id is distinct from v_binding.id;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_binding.reservation_id,'binding_id',v_binding.id,'status',v_binding.status,'idempotent_reuse',true);
 end if;
$old$;
  v_new_binding text := $new$
 if found and v_binding.status in ('held','confirmed') and v_binding.reservation_id is not null then
  select * into v_existing_reservation
  from public.krim_capacity_reservations
  where id=v_binding.reservation_id
  for update;
  if not found
     or v_existing_reservation.status not in ('held','confirmed')
     or v_existing_reservation.organization_id is distinct from v_assignment.partner_organization_id
     or v_existing_reservation.shipment_id is distinct from v_assignment.shipment_id
     or v_existing_reservation.shipment_leg_id is distinct from v_leg.id
     or v_existing_reservation.capacity_availability_id is distinct from v_binding.capacity_availability_id
     or v_binding.shipment_id is distinct from v_assignment.shipment_id
     or v_binding.shipment_leg_id is distinct from v_leg.id
     or v_binding.idempotency_key is distinct from p_idempotency_key
     or v_existing_reservation.idempotency_key is distinct from p_idempotency_key
     or v_existing_reservation.metadata->>'assignment_id' is distinct from v_assignment.id::text
     or not pg_catalog.pg_input_is_valid(v_existing_reservation.metadata->>'planned_departure','timestamp with time zone')
     or not pg_catalog.pg_input_is_valid(v_existing_reservation.metadata->>'planned_arrival','timestamp with time zone')
     or (v_existing_reservation.metadata->>'planned_departure')::timestamptz is distinct from p_planned_departure
     or (v_existing_reservation.metadata->>'planned_arrival')::timestamptz is distinct from p_planned_arrival then
    raise exception using errcode='23505',message='Existing leg capacity is bound to a different assignment or reservation request';
  end if;
  update public.krim_shipment_partner_assignments set capacity_binding_id=v_binding.id,updated_at=now()
   where id=v_assignment.id and capacity_binding_id is distinct from v_binding.id;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_binding.reservation_id,'binding_id',v_binding.id,'status',v_binding.status,'idempotent_reuse',true);
 end if;
$ new$;
  v_old_key text := $old$
 if v_reservation_id is not null then
  if not exists(select 1 from public.krim_capacity_reservations r where r.id=v_reservation_id and r.shipment_id=v_assignment.shipment_id and r.shipment_leg_id=v_leg.id) then
   raise exception using errcode='23505',message='Idempotency key has already been used for another shipment leg';
  end if;
  if v_reservation_status not in ('held','confirmed') then raise exception using errcode='55000',message='This idempotency key belongs to a released or inactive reservation';end if;
  if v_binding_id is null then raise exception using errcode='55000',message='Existing reservation has no linked capacity binding; contact platform operations';end if;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_reservation_id,'binding_id',v_binding_id,'status',v_reservation_status,'idempotent_reuse',true);
 end if;
$old$;
  v_new_key text := $new$
 if v_reservation_id is not null then
  select * into v_existing_reservation from public.krim_capacity_reservations where id=v_reservation_id for update;
  if v_existing_reservation.shipment_id is distinct from v_assignment.shipment_id
     or v_existing_reservation.shipment_leg_id is distinct from v_leg.id
     or v_existing_reservation.organization_id is distinct from v_assignment.partner_organization_id then
   raise exception using errcode='23505',message='Idempotency key has already been used for another shipment, leg or partner';
  end if;
  if v_reservation_status not in ('held','confirmed') then raise exception using errcode='55000',message='This idempotency key belongs to a released or inactive reservation';end if;
  if v_binding_id is null then raise exception using errcode='55000',message='Existing reservation has no linked capacity binding; contact platform operations';end if;
  if not exists (
    select 1 from public.krim_capacity_leg_bindings b
    where b.id=v_binding_id and b.reservation_id=v_reservation_id
      and b.shipment_id=v_assignment.shipment_id and b.shipment_leg_id=v_leg.id
      and b.status in ('held','confirmed') and b.idempotency_key=p_idempotency_key
  ) or v_existing_reservation.idempotency_key is distinct from p_idempotency_key
     or v_existing_reservation.metadata->>'assignment_id' is distinct from v_assignment.id::text
     or not pg_catalog.pg_input_is_valid(v_existing_reservation.metadata->>'planned_departure','timestamp with time zone')
     or not pg_catalog.pg_input_is_valid(v_existing_reservation.metadata->>'planned_arrival','timestamp with time zone')
     or (v_existing_reservation.metadata->>'planned_departure')::timestamptz is distinct from p_planned_departure
     or (v_existing_reservation.metadata->>'planned_arrival')::timestamptz is distinct from p_planned_arrival then
    raise exception using errcode='23505',message='Idempotency key replay conflicts with the original capacity request';
  end if;
  return jsonb_build_object('assignment_id',v_assignment.id,'reservation_id',v_reservation_id,'binding_id',v_binding_id,'status',v_reservation_status,'idempotent_reuse',true);
 end if;
$ new$;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_partner_reserve_shipment_leg_capacity'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_assignment_id bigint, p_planned_departure timestamp with time zone, p_planned_arrival timestamp with time zone, p_idempotency_key text';

  IF v_definition IS NULL OR md5(v_definition) <> v_expected_md5 THEN
    RAISE EXCEPTION 'Reservation function drift detected; refusing automatic patch';
  END IF;

  IF position(v_old_binding in v_definition)=0 OR position(v_old_key in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected reservation replay blocks not found';
  END IF;

  v_definition := replace(v_definition,
    ' v_binding public.krim_capacity_leg_bindings%rowtype;',
    ' v_binding public.krim_capacity_leg_bindings%rowtype;'||E'\n v_existing_reservation public.krim_capacity_reservations%rowtype;');
  v_definition := replace(v_definition,v_old_binding,v_new_binding);
  v_definition := replace(v_definition,v_old_key,v_new_key);
  v_definition := replace(v_definition,
    '''reserved_by'',v_user_id)',
    '''reserved_by'',v_user_id,''assignment_id'',v_assignment.id)');
  IF position('Existing leg capacity is bound to a different assignment or reservation request' in v_definition)=0
     OR position('Idempotency key replay conflicts with the original capacity request' in v_definition)=0
     OR position('''assignment_id'',v_assignment.id' in v_definition)=0 THEN
    RAISE EXCEPTION 'Reservation idempotency patch verification failed';
  END IF;
  EXECUTE v_definition;
END
$migration$;
