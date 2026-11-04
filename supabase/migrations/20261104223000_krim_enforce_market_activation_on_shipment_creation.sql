create or replace function public.krim_create_global_shipment(
 p_customer_organization_id bigint,p_origin_location_id bigint,p_destination_location_id bigint,
 p_goods_description text default null,p_total_weight_kg numeric default null
) returns public.krim_shipments
language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare v_shipment public.krim_shipments%rowtype; v_origin_country_id bigint; v_destination_country_id bigint;
begin
 if p_customer_organization_id is null then raise exception 'Customer organization is required'; end if;
 if not exists(select 1 from public.krim_organizations where id=p_customer_organization_id) then
  raise exception 'Customer organization % not found',p_customer_organization_id; end if;
 if not public.krim_has_organization_access(auth.uid(),p_customer_organization_id) then raise exception 'Organization access denied'; end if;
 if not public.krim_has_permission(auth.uid(),p_customer_organization_id,'shipment.create') then raise exception 'Permission denied: shipment.create'; end if;
 if p_origin_location_id is null or p_destination_location_id is null then raise exception 'Origin and destination locations are required'; end if;
 if p_origin_location_id=p_destination_location_id then raise exception 'Origin and destination must be different locations'; end if;
 select l.country_id into v_origin_country_id from public.krim_locations l join public.krim_countries c on c.id=l.country_id and c.is_active=true
 where l.id=p_origin_location_id and l.is_active=true;
 if v_origin_country_id is null then raise exception 'Origin location is not active or its country is not active'; end if;
 select l.country_id into v_destination_country_id from public.krim_locations l join public.krim_countries c on c.id=l.country_id and c.is_active=true
 where l.id=p_destination_location_id and l.is_active=true;
 if v_destination_country_id is null then raise exception 'Destination location is not active or its country is not active'; end if;
 if not private.krim_market_country_operational(v_origin_country_id) then
  raise exception using errcode='42501',message='Origin market is not operationally activated. Bookings are blocked until all market readiness gates and approvals are complete.'; end if;
 if not private.krim_market_country_operational(v_destination_country_id) then
  raise exception using errcode='42501',message='Destination market is not operationally activated. Bookings are blocked until all market readiness gates and approvals are complete.'; end if;
 if p_total_weight_kg is not null and p_total_weight_kg<0 then raise exception 'Total weight cannot be negative'; end if;
 insert into public.krim_shipments(customer_organization_id,origin_location_id,destination_location_id,goods_description,total_weight_kg,status)
 values(p_customer_organization_id,p_origin_location_id,p_destination_location_id,p_goods_description,p_total_weight_kg,'draft')
 returning * into v_shipment;
 return v_shipment;
end;
$function$;