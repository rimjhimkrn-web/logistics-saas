create or replace function krim_internal.release_capacity_on_shipment_terminal()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare
 v_binding public.krim_capacity_leg_bindings%rowtype;
 v_reservation public.krim_capacity_reservations%rowtype;
 v_org_id bigint;
begin
 if new.status in ('cancelled','completed','delivered','failed') and old.status is distinct from new.status then
  for v_binding in select b.* from public.krim_capacity_leg_bindings b where b.shipment_id=new.id and b.status in ('held','confirmed') for update loop
   v_org_id:=null;v_reservation:=null;
   if v_binding.reservation_id is not null then
    select * into v_reservation from public.krim_capacity_reservations where id=v_binding.reservation_id for update;
    if found then
     v_org_id:=v_reservation.organization_id;
     if v_reservation.status in ('held','confirmed') then
      update public.krim_capacity_reservations set status='released',released_at=now(),release_reason='shipment_terminal:'||new.status,updated_at=now() where id=v_reservation.id;
      insert into public.krim_capacity_reservation_events(reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
      values(v_reservation.id,'capacity_released',v_reservation.status,'released',auth.uid(),'Shipment entered terminal state: '||new.status,jsonb_build_object('shipment_id',new.id));
     end if;
    end if;
   end if;
   if v_org_id is null then
    select a.partner_organization_id into v_org_id from public.krim_shipment_partner_assignments a where a.capacity_binding_id=v_binding.id order by a.created_at desc limit 1;
   end if;
   update public.krim_capacity_leg_bindings set status='released',released_at=now(),release_reason='shipment_terminal:'||new.status,updated_at=now() where id=v_binding.id;
   insert into public.krim_capacity_leg_binding_events(binding_id,event_type,previous_status,new_status,actor_user_id,payload)
   values(v_binding.id,'capacity_released',v_binding.status,'released',auth.uid(),jsonb_build_object('shipment_id',new.id,'terminal_shipment_status',new.status));
   insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
   values(auth.uid(),v_org_id,'partner.capacity.released','capacity_binding',v_binding.id::text,'shipment_lifecycle',
    jsonb_build_object('shipment_id',new.id,'reason','shipment_terminal:'||new.status),
    jsonb_build_object('binding_status',v_binding.status,'reservation_id',v_binding.reservation_id),jsonb_build_object('binding_status','released'));
  end loop;
 end if;
 return new;
end;
$function$;
revoke all on function krim_internal.release_capacity_on_shipment_terminal() from public,anon,authenticated;