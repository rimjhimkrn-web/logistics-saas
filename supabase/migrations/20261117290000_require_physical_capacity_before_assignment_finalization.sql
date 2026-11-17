-- Keep accepted partner assignments pending until physical verified capacity is reserved.
-- Capacity reservation finalizes an already customer-confirmed shipment.
DO $migration$
DECLARE
  v_def text;
  v_new text;
  v_count integer;
BEGIN
  -- A partner's acceptance must not finalize a confirmed shipment until physical
  -- route capacity has been reserved against a verified resource.
  SELECT pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure)
    INTO v_def;

  v_new := replace(
    v_def,
    $old$if v_shipment.status='confirmed' then
      v_finalize_result := public.krim_internal_finalize_partner_assignment(v_assignment.id);$old$,
    $new$if v_shipment.status='confirmed' and not exists (
        select 1
        from public.krim_capacity_leg_bindings b
        join public.krim_capacity_reservations r on r.id=b.reservation_id
        where b.id=v_assignment.capacity_binding_id
          and b.shipment_leg_id=v_assignment.shipment_leg_id
          and b.status='confirmed' and r.status='confirmed'
      ) then
      v_finalize_result := jsonb_build_object('assigned',false,'deferred',true,
        'assignment_id',v_assignment.id,'shipment_id',v_shipment.id,
        'next_step','partner_capacity_reservation');
    elsif v_shipment.status='confirmed' then
      v_finalize_result := public.krim_internal_finalize_partner_assignment(v_assignment.id);$new$
  );

  IF v_new = v_def THEN
    RAISE EXCEPTION 'Could not locate confirmed-shipment finalization gate in partner response RPC';
  END IF;
  EXECUTE v_new;

  -- Once a partner has reserved the exact leg's verified resource capacity,
  -- finalize a previously accepted assignment if the customer shipment is confirmed.
  SELECT pg_get_functiondef(
    'public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure
  ) INTO v_def;

  v_new := replace(
    v_def,
    $old$return jsonb_build_object('assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'reservation_id',v_reservation_id,$old$,
    $new$IF v_shipment.status='confirmed' THEN
  PERFORM public.krim_internal_finalize_partner_assignment(v_assignment.id);
 END IF;
 return jsonb_build_object('assignment_id',v_assignment.id,'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'reservation_id',v_reservation_id,$new$
  );

  IF v_new = v_def THEN
    RAISE EXCEPTION 'Could not locate reservation success return point';
  END IF;
  EXECUTE v_new;
END
$migration$;
