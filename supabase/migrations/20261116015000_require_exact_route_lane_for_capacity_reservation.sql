DO $migration$
DECLARE
  v_def text;
  v_old text := $old$  from public.krim_partner_capacity_availability a join public.krim_capacity_resources r on r.id=a.capacity_resource_id
  where a.organization_id=v_assignment.partner_organization_id and a.transport_mode_id=v_leg.transport_mode_id
   and a.status='available' and a.metadata->>'verification_state'='verified'$old$;
  v_new text := $new$  from public.krim_partner_capacity_availability a
  join public.krim_capacity_resources r on r.id=a.capacity_resource_id
  join public.krim_network_lanes nl
    on nl.id=a.lane_id
   and nl.origin_location_id=v_leg.origin_location_id
   and nl.destination_location_id=v_leg.destination_location_id
   and nl.transport_mode_id=v_leg.transport_mode_id
   and nl.status='active'
  where a.organization_id=v_assignment.partner_organization_id
   and a.transport_mode_id=v_leg.transport_mode_id
   and r.transport_mode_id=v_leg.transport_mode_id
   and a.status='available' and a.metadata->>'verification_state'='verified'$new$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef(
    'public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure
  ) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN
    RAISE EXCEPTION 'Expected capacity availability selection block not found; no change applied';
  END IF;
  v_def:=pg_catalog.replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
