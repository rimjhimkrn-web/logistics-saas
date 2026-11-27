create or replace function public.krim_internal_expire_capacity_holds(p_batch_size integer default 200)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reservation record;
  v_binding record;
  v_assignment record;
  v_count integer := 0;
begin
  if p_batch_size is null or p_batch_size < 1 or p_batch_size > 2000 then
    raise exception using errcode='22023', message='Batch size must be between 1 and 2000';
  end if;

  for v_reservation in
    select r.id,r.status,r.shipment_id,r.shipment_leg_id,
           r.organization_id,r.capacity_availability_id
    from public.krim_capacity_reservations r
    where r.status='held' and r.hold_expires_at is not null
      and r.hold_expires_at <= pg_catalog.now()
    order by r.hold_expires_at,r.id
    for update skip locked
    limit p_batch_size
  loop
    update public.krim_capacity_reservations
    set status='expired',released_at=pg_catalog.now(),
        release_reason='Capacity hold expired automatically',updated_at=pg_catalog.now()
    where id=v_reservation.id and status='held';

    if found then
      insert into public.krim_capacity_reservation_events
        (reservation_id,event_type,previous_status,new_status,event_time,actor_user_id,reason,payload)
      values
        (v_reservation.id,'hold_expired',v_reservation.status,'expired',
         pg_catalog.now(),null,'Capacity hold expired automatically',
         pg_catalog.jsonb_build_object('source','scheduled_expiry_worker'));

      for v_binding in
        select b.id,b.status,b.shipment_id,b.shipment_leg_id,
               b.capacity_availability_id
        from public.krim_capacity_leg_bindings b
        where b.reservation_id=v_reservation.id
          and b.status in ('pending','held','confirmed')
        for update
      loop
        if v_binding.shipment_id is distinct from v_reservation.shipment_id
           or v_binding.shipment_leg_id is distinct from v_reservation.shipment_leg_id
           or v_binding.capacity_availability_id is distinct from v_reservation.capacity_availability_id then
          raise exception using errcode='23514',
            message='Expired reservation is linked to a mismatched shipment, leg or availability binding';
        end if;

        for v_assignment in
          select a.id,a.partner_organization_id,a.capacity_binding_id
          from public.krim_shipment_partner_assignments a
          where a.capacity_binding_id=v_binding.id
          for update
        loop
          if v_assignment.partner_organization_id is distinct from v_reservation.organization_id
             or not exists (
               select 1 from public.krim_partner_capacity_availability av
               where av.id=v_reservation.capacity_availability_id
                 and av.organization_id=v_assignment.partner_organization_id
             ) then
            raise exception using errcode='23514',
              message='Expired reservation assignment does not match the capacity partner';
          end if;

          update public.krim_partner_shipment_capacity_commitments c
          set status='expired',updated_at=pg_catalog.now(),
              metadata=coalesce(c.metadata,'{}'::jsonb) ||
                pg_catalog.jsonb_build_object(
                  'capacity_expiry_source','scheduled_expiry_worker',
                  'capacity_reservation_id',v_reservation.id,
                  'capacity_binding_id',v_binding.id,
                  'capacity_expired_at',pg_catalog.now(),
                  'reconciled_previous_binding_status',v_binding.status)
          where c.status='committed' and c.assignment_id=v_assignment.id;

          update public.krim_shipment_partner_assignments
          set capacity_binding_id=null,updated_at=pg_catalog.now()
          where id=v_assignment.id and capacity_binding_id=v_binding.id;
        end loop;

        update public.krim_capacity_leg_bindings
        set status='expired',released_at=pg_catalog.now(),
            release_reason='Linked capacity reservation expired',updated_at=pg_catalog.now()
        where id=v_binding.id and status=v_binding.status;

        if found then
          insert into public.krim_capacity_leg_binding_events
            (binding_id,event_type,previous_status,new_status,event_time,actor_user_id,payload)
          values
            (v_binding.id,'reservation_expired',v_binding.status,'expired',
             pg_catalog.now(),null,
             pg_catalog.jsonb_build_object('reservation_id',v_reservation.id,
               'source','scheduled_expiry_worker',
               'reconciled_previous_binding_status',v_binding.status));
        end if;
      end loop;

      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$function$;
