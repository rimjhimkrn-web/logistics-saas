-- Revalidate route-specific verified capacity immediately before partner quote award.
do $block$
declare v_definition text;
begin
 select pg_catalog.pg_get_functiondef('public.krim_award_partner_quote(bigint)'::regprocedure) into v_definition;
 if position('krim_internal_partner_has_verified_capacity' in v_definition)=0 then
  v_definition:=replace(v_definition,
   '  v_leg_id bigint;',
   '  v_leg_id bigint;'||
   '  v_mode_id bigint;'||
   '  v_service_date date;');
  v_definition:=replace(v_definition,
   '  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN'||E'\n    RAISE EXCEPTION USING errcode=''42501'', message=''Partner capability no longer covers the shipment route, transport mode or weight'';'||E'\n  END IF;',
   '  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN'||E'\n    RAISE EXCEPTION USING errcode=''42501'', message=''Partner capability no longer covers the shipment route, transport mode or weight'';'||E'\n  END IF;'||E'\n  SELECT id INTO v_mode_id FROM public.krim_transport_modes WHERE upper(code)=upper(v_shipment.requested_transport_mode) AND is_active IS TRUE LIMIT 1;'||E'\n  SELECT csr.requested_service_date INTO v_service_date FROM public.krim_customer_service_requests csr WHERE csr.id=nullif(v_opportunity.metadata->>''service_request_id'','''')::bigint;'||E'\n  IF v_mode_id IS NULL OR NOT private.krim_internal_partner_has_verified_capacity(v_quote.partner_organization_id,v_shipment.origin_location_id,v_shipment.destination_location_id,v_mode_id,v_shipment.total_weight_kg,coalesce(v_service_date,current_date)) THEN'||E'\n    RAISE EXCEPTION USING errcode=''42501'', message=''Verified route capacity is no longer available for the requested service date; refresh matching before award'';'||E'\n  END IF;');
  if position('krim_internal_partner_has_verified_capacity' in v_definition)=0 then raise exception 'Could not add capacity revalidation to shipment award'; end if;
  execute v_definition;
 end if;

 select pg_catalog.pg_get_functiondef('public.krim_award_leg_partner_quote(bigint)'::regprocedure) into v_definition;
 if position('krim_internal_partner_has_verified_capacity' in v_definition)=0 then
  v_definition:=replace(v_definition,
   '  v_number text;',
   '  v_number text;'||
   '  v_service_date date;');
  v_definition:=replace(v_definition,
   '  SELECT * INTO v_assignment FROM public.krim_shipment_partner_assignments',
   '  SELECT csr.requested_service_date INTO v_service_date FROM public.krim_customer_service_requests csr WHERE csr.id=nullif(v_opportunity.metadata->>''service_request_id'','''')::bigint;'||E'\n  IF NOT private.krim_internal_partner_has_verified_capacity(v_quote.partner_organization_id,v_leg.origin_location_id,v_leg.destination_location_id,v_leg.transport_mode_id,v_shipment.total_weight_kg,coalesce(v_service_date,current_date)) THEN'||E'\n    RAISE EXCEPTION USING ERRCODE=''42501'', MESSAGE=''Verified route capacity is no longer available for the requested service date; refresh matching before award'';'||E'\n  END IF;'||E'\n  SELECT * INTO v_assignment FROM public.krim_shipment_partner_assignments');
  if position('krim_internal_partner_has_verified_capacity' in v_definition)=0 then raise exception 'Could not add capacity revalidation to leg award'; end if;
  execute v_definition;
 end if;
end
$block$;
