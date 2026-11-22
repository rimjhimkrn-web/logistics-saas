create or replace function public.krim_create_global_shipment_from_locations_idempotent(
  p_customer_organization_id bigint,
  p_origin_location_id bigint,
  p_destination_location_id bigint,
  p_goods_description text,
  p_total_weight_kg numeric,
  p_transport_mode text,
  p_route_type text,
  p_booking_request_id uuid
)
returns public.krim_shipments
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_org public.krim_organizations%rowtype;
  v_origin public.krim_locations%rowtype;
  v_destination public.krim_locations%rowtype;
  v_origin_country public.krim_countries%rowtype;
  v_destination_country public.krim_countries%rowtype;
  v_shipment public.krim_shipments%rowtype;
  v_goods text := btrim(coalesce(p_goods_description, ''));
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if p_customer_organization_id is null or p_origin_location_id is null
     or p_destination_location_id is null or p_booking_request_id is null then
    raise exception using errcode = '22023', message = 'Organization, route locations and booking reference are required';
  end if;
  if p_origin_location_id = p_destination_location_id then
    raise exception using errcode = '22023', message = 'Origin and destination must be different locations';
  end if;
  if not private.krim_has_organization_access(v_user_id, p_customer_organization_id) then
    raise exception using errcode = '42501', message = 'Organization access denied';
  end if;
  if not private.krim_has_permission(v_user_id, p_customer_organization_id, 'shipment.create') then
    raise exception using errcode = '42501', message = 'Permission denied: shipment.create';
  end if;
  select * into v_org from public.krim_organizations
  where id = p_customer_organization_id and status = 'active'
    and organization_type in ('customer', 'shipper', 'enterprise');
  if not found then
    raise exception using errcode = '42501', message = 'Shipment creation requires an active customer, shipper or enterprise organization';
  end if;
  if v_goods = '' or char_length(v_goods) > 500 then
    raise exception using errcode = '22023', message = 'Goods description is required and must be 500 characters or fewer';
  end if;
  if p_total_weight_kg is null or p_total_weight_kg <= 0 or p_total_weight_kg > 100000000 then
    raise exception using errcode = '22023', message = 'Shipment weight must be greater than zero and within the supported range';
  end if;
  if p_transport_mode is null or p_transport_mode not in
    ('road', 'rail', 'ocean', 'air', 'multimodal', 'warehouse_transfer', 'specialist') then
    raise exception using errcode = '22023', message = 'Choose a supported transport mode';
  end if;
  if p_route_type is null or p_route_type not in
    ('door_to_door', 'airport_to_airport', 'port_to_port', 'terminal_to_terminal',
     'warehouse_to_warehouse', 'domestic', 'cross_border', 'first_last_mile', 'multimodal_end_to_end') then
    raise exception using errcode = '22023', message = 'Choose a supported route type';
  end if;
  select * into v_origin from public.krim_locations
  where id = p_origin_location_id and is_active is true;
  if not found then
    raise exception using errcode = '22023', message = 'The selected origin is not an active KRIM location';
  end if;
  select * into v_destination from public.krim_locations
  where id = p_destination_location_id and is_active is true;
  if not found then
    raise exception using errcode = '22023', message = 'The selected destination is not an active KRIM location';
  end if;
  select * into v_origin_country from public.krim_countries
  where id = v_origin.country_id and is_active is true;
  if not found then
    raise exception using errcode = '22023', message = 'The selected origin country is not active';
  end if;
  select * into v_destination_country from public.krim_countries
  where id = v_destination.country_id and is_active is true;
  if not found then
    raise exception using errcode = '22023', message = 'The selected destination country is not active';
  end if;
  if p_route_type = 'domestic' and v_origin_country.code <> v_destination_country.code then
    raise exception using errcode = '22023', message = 'Domestic route type requires both locations to be in the same country';
  end if;
  if p_route_type = 'cross_border' and v_origin_country.code = v_destination_country.code then
    raise exception using errcode = '22023', message = 'Cross-border route type requires locations in different countries';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_customer_organization_id::text || ':' || p_booking_request_id::text, 0)
  );
  select * into v_shipment from public.krim_shipments
  where customer_organization_id = p_customer_organization_id
    and booking_request_id = p_booking_request_id limit 1;
  if found then
    if v_shipment.origin_location_id is distinct from p_origin_location_id
       or v_shipment.destination_location_id is distinct from p_destination_location_id
       or v_shipment.goods_description is distinct from v_goods
       or v_shipment.total_weight_kg is distinct from p_total_weight_kg
       or v_shipment.requested_transport_mode is distinct from p_transport_mode
       or v_shipment.requested_route_type is distinct from p_route_type then
      raise exception using errcode = '22023',
        message = 'This booking reference was already used with different shipment details. Check My Shipments before starting another request.';
    end if;
    return v_shipment;
  end if;

  insert into public.krim_shipments (
    customer_organization_id, origin_location_id, destination_location_id,
    goods_description, total_weight_kg, status, requested_transport_mode,
    requested_route_type, origin_place_label, destination_place_label,
    origin_place_type, destination_place_type, origin_latitude, origin_longitude,
    destination_latitude, destination_longitude, booking_request_id
  ) values (
    p_customer_organization_id, p_origin_location_id, p_destination_location_id,
    v_goods, p_total_weight_kg, 'draft', p_transport_mode, p_route_type,
    pg_catalog.concat_ws(' · ', v_origin.city, coalesce(v_origin.state_region, v_origin.region), v_origin_country.name),
    pg_catalog.concat_ws(' · ', v_destination.city, coalesce(v_destination.state_region, v_destination.region), v_destination_country.name),
    coalesce(v_origin.location_type, 'location'), coalesce(v_destination.location_type, 'location'),
    v_origin.latitude, v_origin.longitude, v_destination.latitude, v_destination.longitude,
    p_booking_request_id
  ) returning * into v_shipment;
  return v_shipment;
end;
$function$;

revoke all on function public.krim_create_global_shipment_from_locations_idempotent(bigint,bigint,bigint,text,numeric,text,text,uuid) from public;
revoke all on function public.krim_create_global_shipment_from_locations_idempotent(bigint,bigint,bigint,text,numeric,text,text,uuid) from anon;
grant execute on function public.krim_create_global_shipment_from_locations_idempotent(bigint,bigint,bigint,text,numeric,text,text,uuid) to authenticated;
