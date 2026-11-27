create or replace function krim_internal.release_capacity_on_shipment_terminal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_binding public.krim_capacity_leg_bindings%rowtype;
  v_reservation public.krim_capacity_reservations%rowtype;
  v_org_id bigint;
  v_commitment_status text;
begin
  if new.status not in ('cancelled','completed','delivered','failed')
     or old.status is not distinct from new.status then
    return new;
  end if;

  v_commitment_status := case
    when new.status='cancelled' then 'cancelled'
    when new.status='failed' then 'expired'
    else 'released'
  end;

  for v_binding in
    select b.* from public.krim_capacity_leg_bindings b
    where b.shipment_id=new.id and b.status in ('pending','held','confirmed')
    for update
  loop
    if v_binding.shipment_id is distinct from new.id then
      raise exception using errcode='23514',
        message='Capacity binding does not belong to the terminal shipment';
    end if;

    v_org_id := null;
    v_reservation := null;

    if v_binding.reservation_id is not null then
      select * into v_reservation
      from public.krim_capacity_reservations r
      where r.id=v_binding.reservation_id
      for update;

      if not found
         or v_reservation.shipment_id is distinct from new.id
         or v_reservation.shipment_leg_id is distinct from v_binding.shipment_leg_id
         or v_reservation.capacity_availability_id is distinct from v_binding.capacity_availability_id
         or not exists (
           select 1 from public.krim_partner_capacity_availability av
           where av.id=v_binding.capacity_availability_id
             and av.organization_id=v_reservation.organization_id
         ) then
        raise exception using errcode='23514',
          message='Capacity reservation lineage does not match the exact shipment, leg, availability and partner';
      end if;

      v_org_id := v_reservation.organization_id;

      if v_reservation.status in ('held','confirmed') then
        update public.krim_capacity_reservations
        set status='released',released_at=pg_catalog.now(),
            release_reason='shipment_terminal:'||new.status,updated_at=pg_catalog.now()
        where id=v_reservation.id;

        insert into public.krim_capacity_reservation_events
          (reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
        values
          (v_reservation.id,'capacity_released',v_reservation.status,'released',
           auth.uid(),'Shipment entered terminal state: '||new.status,
           pg_catalog.jsonb_build_object('shipment_id',new.id,'shipment_leg_id',v_binding.shipment_leg_id,'binding_id',v_binding.id));
      end if;
    elsif v_binding.status in ('held','confirmed') then
      raise exception using errcode='23514',
        message='Live capacity binding is missing its reservation lineage';
    end if;

    if v_org_id is null then
      select av.organization_id into v_org_id
      from public.krim_partner_capacity_availability av
      where av.id=v_binding.capacity_availability_id;
    end if;

    update public.krim_capacity_leg_bindings
    set status='released',released_at=pg_catalog.now(),
        release_reason='shipment_terminal:'||new.status,updated_at=pg_catalog.now()
    where id=v_binding.id;

    insert into public.krim_capacity_leg_binding_events
      (binding_id,event_type,previous_status,new_status,actor_user_id,payload)
    values
      (v_binding.id,'capacity_released',v_binding.status,'released',auth.uid(),
       pg_catalog.jsonb_build_object('shipment_id',new.id,'shipment_leg_id',v_binding.shipment_leg_id,'terminal_shipment_status',new.status,'reservation_id',v_binding.reservation_id));

    insert into public.krim_audit_events
      (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
    values
      (auth.uid(),v_org_id,'partner.capacity.released','capacity_binding',
       v_binding.id::text,'shipment_lifecycle',
       pg_catalog.jsonb_build_object('shipment_id',new.id,'shipment_leg_id',v_binding.shipment_leg_id,'reason','shipment_terminal:'||new.status),
       pg_catalog.jsonb_build_object('binding_status',v_binding.status,'reservation_id',v_binding.reservation_id),
       pg_catalog.jsonb_build_object('binding_status','released'));
  end loop;

  update public.krim_partner_shipment_capacity_commitments c
  set status=v_commitment_status,updated_at=pg_catalog.now(),
      metadata=coalesce(c.metadata,'{}'::jsonb) ||
        pg_catalog.jsonb_build_object('terminal_shipment_status',new.status,
          'capacity_released_at',pg_catalog.now(),
          'capacity_release_reason','shipment_terminal:'||new.status)
  where c.status='committed'
    and c.assignment_id in (
      select a.id from public.krim_shipment_partner_assignments a where a.shipment_id=new.id
    );

  update public.krim_shipment_partner_assignments a
  set capacity_binding_id=null,updated_at=pg_catalog.now()
  where a.shipment_id=new.id and a.capacity_binding_id is not null
    and exists (
      select 1 from public.krim_capacity_leg_bindings b
      where b.id=a.capacity_binding_id
        and b.shipment_id=a.shipment_id
        and b.shipment_leg_id=a.shipment_leg_id
        and b.status='released'
    );

  return new;
end;
$function$;
