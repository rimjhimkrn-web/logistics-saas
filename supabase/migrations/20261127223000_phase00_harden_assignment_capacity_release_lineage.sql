-- Phase 00: make assignment-terminal capacity cleanup exact and clear stale references.
create or replace function krim_internal.release_capacity_on_assignment_terminal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_binding public.krim_capacity_leg_bindings%rowtype;
  v_reservation public.krim_capacity_reservations%rowtype;
  v_commitment_status text;
begin
  if new.status not in ('rejected','cancelled','completed','failed')
     or old.status is not distinct from new.status then
    return new;
  end if;

  v_commitment_status := case
    when new.status='rejected'
      and new.rejection_reason in (
        'Partner response deadline or quote validity expired automatically',
        'Customer quote expired before final acceptance'
      ) then 'expired'
    when new.status in ('rejected','cancelled') then 'cancelled'
    when new.status='failed' then 'expired'
    else 'released'
  end;

  update public.krim_partner_shipment_capacity_commitments
  set status=v_commitment_status,
      updated_at=pg_catalog.now(),
      metadata=coalesce(metadata,'{}'::jsonb) ||
        pg_catalog.jsonb_build_object(
          'terminal_assignment_status',new.status,
          'capacity_released_at',pg_catalog.now(),
          'capacity_release_reason',coalesce(new.rejection_reason,new.status)
        )
  where assignment_id=new.id and status='committed';

  if new.capacity_binding_id is null then
    return new;
  end if;

  select * into v_binding
  from public.krim_capacity_leg_bindings
  where id=new.capacity_binding_id
  for update;

  if found then
    if v_binding.shipment_id is distinct from new.shipment_id
       or v_binding.shipment_leg_id is distinct from new.shipment_leg_id then
      raise exception using errcode='23514',
        message='Assignment capacity binding does not match the assignment shipment and leg';
    end if;

    if v_binding.status in ('pending','held','confirmed') then
      if v_binding.reservation_id is not null then
        select * into v_reservation
        from public.krim_capacity_reservations
        where id=v_binding.reservation_id
        for update;

        if not found
           or v_reservation.shipment_id is distinct from new.shipment_id
           or v_reservation.shipment_leg_id is distinct from new.shipment_leg_id
           or v_reservation.organization_id is distinct from new.partner_organization_id then
          raise exception using errcode='23514',
            message='Capacity reservation does not match the exact assignment, shipment, leg and partner';
        end if;

        if v_reservation.status in ('held','confirmed') then
          update public.krim_capacity_reservations
          set status='released',
              released_at=pg_catalog.now(),
              release_reason='assignment_terminal:'||new.status,
              updated_at=pg_catalog.now()
          where id=v_reservation.id;

          insert into public.krim_capacity_reservation_events
            (reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
          values
            (v_reservation.id,'capacity_released',v_reservation.status,'released',
             auth.uid(),'Assignment entered terminal state: '||new.status,
             pg_catalog.jsonb_build_object('assignment_id',new.id,'shipment_id',new.shipment_id,'shipment_leg_id',new.shipment_leg_id));
        end if;
      end if;

      update public.krim_capacity_leg_bindings
      set status='released',released_at=pg_catalog.now(),
          release_reason='assignment_terminal:'||new.status,
          updated_at=pg_catalog.now()
      where id=v_binding.id;

      insert into public.krim_capacity_leg_binding_events
        (binding_id,event_type,previous_status,new_status,actor_user_id,payload)
      values
        (v_binding.id,'capacity_released',v_binding.status,'released',auth.uid(),
         pg_catalog.jsonb_build_object('assignment_id',new.id,'terminal_assignment_status',new.status));

      insert into public.krim_audit_events
        (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
      values
        (auth.uid(),new.partner_organization_id,'partner.capacity.released',
         'capacity_binding',v_binding.id::text,'assignment_lifecycle',
         pg_catalog.jsonb_build_object('assignment_id',new.id,'reason','assignment_terminal:'||new.status),
         pg_catalog.jsonb_build_object('binding_status',v_binding.status,'reservation_id',v_binding.reservation_id),
         pg_catalog.jsonb_build_object('binding_status','released'));
    end if;
  end if;

  -- Clear only this assignment's exact pointer; status-only trigger does not recurse.
  update public.krim_shipment_partner_assignments
  set capacity_binding_id=null,updated_at=pg_catalog.now()
  where id=new.id and capacity_binding_id=new.capacity_binding_id;

  return new;
end;
$function$;
