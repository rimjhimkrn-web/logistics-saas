create or replace function private.krim_enforce_market_activation_on_shipment_write()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_origin_country_id bigint; v_destination_country_id bigint;
begin
 select country_id into v_origin_country_id from public.krim_locations
 where id=new.origin_location_id and is_active=true;
 select country_id into v_destination_country_id from public.krim_locations
 where id=new.destination_location_id and is_active=true;
 if v_origin_country_id is null or v_destination_country_id is null then
  raise exception using errcode='23514',message='Shipment origin and destination must be active locations in valid countries';
 end if;
 if not private.krim_market_country_operational(v_origin_country_id) then
  raise exception using errcode='42501',message='Shipment origin market is not operationally activated; shipment creation is blocked';
 end if;
 if not private.krim_market_country_operational(v_destination_country_id) then
  raise exception using errcode='42501',message='Shipment destination market is not operationally activated; shipment creation is blocked';
 end if;
 return new;
end; $$;
revoke all on function private.krim_enforce_market_activation_on_shipment_write() from public,anon,authenticated;
drop trigger if exists krim_enforce_market_activation_before_shipment_write on public.krim_shipments;
create trigger krim_enforce_market_activation_before_shipment_write
before insert or update of origin_location_id,destination_location_id
on public.krim_shipments
for each row execute function private.krim_enforce_market_activation_on_shipment_write();