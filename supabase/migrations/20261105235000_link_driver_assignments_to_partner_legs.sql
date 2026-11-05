-- Preserve the exact partner assignment/leg when dispatching a driver.
-- This allows driver evidence and delivery milestones to be reconciled to the commercial assignment.
alter table public.krim_driver_assignments
  add column if not exists partner_assignment_id bigint;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.krim_driver_assignments'::regclass
      and conname='krim_driver_assignments_partner_assignment_id_fkey'
  ) then
    alter table public.krim_driver_assignments
      add constraint krim_driver_assignments_partner_assignment_id_fkey
      foreign key (partner_assignment_id)
      references public.krim_shipment_partner_assignments(id)
      on delete set null;
  end if;
end $$;

create unique index if not exists krim_driver_assignments_partner_assignment_uidx
  on public.krim_driver_assignments(partner_assignment_id)
  where partner_assignment_id is not null;

create or replace function public.krim_assign_driver_to_partner_shipment(
 p_partner_assignment_id bigint,
 p_driver_user_id uuid
)
returns public.krim_driver_assignments
language plpgsql
security definer
set search_path to 'public','auth','pg_temp'
as $function$
declare
  v_user uuid := auth.uid();
  v_pa public.krim_shipment_partner_assignments%rowtype;
  v_ship public.krim_shipments%rowtype;
  v_leg public.krim_shipment_legs%rowtype;
  v_driver_org bigint;
  v_pickup text;
  v_delivery text;
  v_dispatch_id bigint;
  v_assignment public.krim_driver_assignments%rowtype;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;

  select * into v_pa
  from public.krim_shipment_partner_assignments
  where id=p_partner_assignment_id and status='accepted'
  for update;
  if not found then
    raise exception using errcode='22023', message='Only an accepted partner assignment can be dispatched';
  end if;

  if not public.krim_has_permission(v_user,v_pa.partner_organization_id,'shipment.dispatch') then
    raise exception using errcode='42501', message='You do not have dispatch permission for this partner organization';
  end if;

  select m.organization_id into v_driver_org
  from public.krim_organization_members m
  join public.krim_organizations o on o.id=m.organization_id and lower(o.status)='active'
  where m.user_id=p_driver_user_id
    and m.organization_id=v_pa.partner_organization_id
    and lower(m.role)='driver'
    and lower(m.status)='active'
  order by m.created_at
  limit 1;
  if v_driver_org is null then
    raise exception using errcode='42501', message='Driver must have an active driver membership in this partner organization';
  end if;

  if not exists (
    select 1 from public.krim_driver_profiles dp
    where dp.user_id=p_driver_user_id
      and dp.organization_id=v_pa.partner_organization_id
      and dp.verification_status in ('verified','approved')
      and nullif(btrim(dp.licence_number),'') is not null
  ) then
    raise exception using errcode='42501', message='Driver identity and licence verification must be approved before dispatch';
  end if;

  select * into v_ship
  from public.krim_shipments
  where id=v_pa.shipment_id
  for update;
  if not found then
    raise exception using errcode='22023', message='Shipment not found';
  end if;

  select * into v_leg
  from public.krim_shipment_legs
  where id=v_pa.shipment_leg_id and shipment_id=v_ship.id
  for update;
  if not found then
    raise exception using errcode='22023', message='The accepted partner assignment must reference a valid leg of this shipment';
  end if;

  if not exists (
    select 1 from public.krim_organizations o
    where o.id=v_pa.partner_organization_id
      and o.status='active'
      and o.partner_account_mode='registered_business'
      and o.partner_verification_status in ('verified','approved')
      and o.partner_lifecycle_status in ('active','verified')
      and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
  ) or not private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) then
    raise exception using errcode='42501', message='Partner commercial eligibility or verified route capability is no longer valid';
  end if;

  select concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,''))
    into v_pickup from public.krim_locations l where l.id=v_leg.origin_location_id;
  select concat_ws(', ',nullif(l.city,''),nullif(l.state_region,''),nullif(l.location_code,''))
    into v_delivery from public.krim_locations l where l.id=v_leg.destination_location_id;
  v_pickup:=coalesce(nullif(v_pickup,''),'Pickup location pending');
  v_delivery:=coalesce(nullif(v_delivery,''),'Delivery location pending');

  if v_ship.legacy_shipment_request_id is not null then
    select d.id into v_dispatch_id
    from public.shipment_dispatches d
    where d.krim_shipment_leg_id=v_pa.shipment_leg_id
      and d.dispatch_status in ('pending','assigned','dispatched','in_transit')
    order by d.created_at desc
    limit 1;
    if v_dispatch_id is null then
      insert into public.shipment_dispatches
        (shipment_id,dispatch_status,dispatch_date,pickup_location,delivery_location,
         krim_shipment_id,krim_shipment_leg_id,notes)
      values
        (v_ship.legacy_shipment_request_id,'dispatched',now(),v_pickup,v_delivery,
         v_ship.id,v_pa.shipment_leg_id,'Driver assigned through KRIM authorized dispatch workflow')
      returning id into v_dispatch_id;
    end if;
  end if;

  select * into v_assignment
  from public.krim_driver_assignments
  where partner_assignment_id=p_partner_assignment_id
  for update;
  if found then
    if v_assignment.user_id<>p_driver_user_id then
      raise exception using errcode='23505', message='This partner shipment leg is already assigned to another driver';
    end if;
    return v_assignment;
  end if;

  insert into public.krim_driver_assignments
    (user_id,organization_id,shipment_id,shipment_dispatch_id,partner_assignment_id,status,
     pickup_location,delivery_location,created_by)
  values
    (p_driver_user_id,v_driver_org,v_ship.id,v_dispatch_id,p_partner_assignment_id,'assigned',
     v_pickup,v_delivery,v_user)
  returning * into v_assignment;

  return v_assignment;
end;
$function$;
