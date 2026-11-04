create or replace function private.krim_market_country_operational(p_country_id bigint)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(
  select 1 from public.krim_markets m
  join public.krim_market_activation_controls c on c.market_id=m.id
  where m.country_id=p_country_id and c.operational_status='active'
   and m.is_active=true and m.status='active'
   and coalesce((public.krim_internal_market_activation_gate(m.id)->>'eligible')::boolean,false)=true
 );
$$;

create or replace function public.krim_create_global_shipment_from_places(
 p_customer_organization_id bigint,p_origin_place jsonb,p_destination_place jsonb,
 p_goods_description text,p_total_weight_kg numeric,p_transport_mode text,p_route_type text
) returns public.krim_shipments
language plpgsql security definer set search_path to 'public','private','pg_temp'
as $function$
declare v_shipment public.krim_shipments%rowtype; v_origin_code text; v_destination_code text;
begin
 if auth.uid() is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if p_route_type is null or p_route_type not in (
  'door_to_door','airport_to_airport','port_to_port','terminal_to_terminal',
  'warehouse_to_warehouse','domestic','cross_border','first_last_mile','multimodal_end_to_end'
 ) then raise exception using errcode='22023',message='Choose a supported route type'; end if;
 v_origin_code:=upper(btrim(coalesce(p_origin_place->>'country_code','')));
 v_destination_code:=upper(btrim(coalesce(p_destination_place->>'country_code','')));
 if v_origin_code !~ '^[A-Z]{2}$' or v_destination_code !~ '^[A-Z]{2}$' then
  raise exception using errcode='22023',message='Both selected places must include valid country codes'; end if;
 if p_route_type='domestic' and v_origin_code<>v_destination_code then
  raise exception using errcode='22023',message='Domestic route type requires origin and destination in the same country'; end if;
 if p_route_type='cross_border' and v_origin_code=v_destination_code then
  raise exception using errcode='22023',message='Cross-border route type requires origin and destination in different countries'; end if;
 v_shipment:=public.krim_create_global_shipment_from_places(
  p_customer_organization_id,p_origin_place,p_destination_place,p_goods_description,p_total_weight_kg,p_transport_mode
 );
 update public.krim_shipments set requested_route_type=p_route_type where id=v_shipment.id returning * into v_shipment;
 return v_shipment;
end;
$function$;