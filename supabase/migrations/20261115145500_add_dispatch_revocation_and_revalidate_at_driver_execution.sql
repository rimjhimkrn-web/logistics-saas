alter table public.krim_shipment_leg_dispatch_authorizations
 add column if not exists revoked_by uuid;

alter table public.krim_shipment_leg_dispatch_authorizations
 drop constraint if exists krim_shipment_leg_dispatch_authorizations_shipment_leg_id_key;
create unique index if not exists uq_krim_active_leg_dispatch_authorization
 on public.krim_shipment_leg_dispatch_authorizations(shipment_leg_id)
 where status='authorized';

create or replace function private.krim_leg_dispatch_authorization_is_current(
 p_shipment_id bigint,p_shipment_leg_id bigint,p_partner_assignment_id bigint,p_partner_organization_id bigint
) returns boolean language sql security definer set search_path='' stable
as $function$
 select exists(
  select 1
  from public.krim_shipment_leg_dispatch_authorizations da
  join public.krim_shipment_legs l on l.id=da.shipment_leg_id and l.shipment_id=da.shipment_id
  join public.krim_shipment_leg_plans p on p.shipment_id=da.shipment_id and p.status='active' and p.total_legs>1
  join public.krim_shipment_leg_plan_items i on i.id=l.leg_plan_item_id and i.plan_id=p.id
   and i.leg_sequence=l.leg_sequence and i.origin_location_id=l.origin_location_id
   and i.destination_location_id=l.destination_location_id and i.transport_mode_id=l.transport_mode_id
   and i.partner_organization_id=da.partner_organization_id and i.assignment_id=da.partner_assignment_id
  join public.krim_shipment_partner_assignments pa on pa.id=da.partner_assignment_id
   and pa.shipment_id=da.shipment_id and pa.shipment_leg_id=da.shipment_leg_id
   and pa.partner_organization_id=da.partner_organization_id and pa.status in ('accepted','active')
  join public.krim_organizations o on o.id=da.partner_organization_id
   and o.status='active' and o.partner_account_mode='registered_business'
   and o.partner_verification_status in ('verified','approved')
   and o.partner_lifecycle_status in ('active','verified')
   and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
  join public.krim_capacity_leg_bindings cb on cb.id=da.capacity_binding_id
   and cb.shipment_id=da.shipment_id and cb.shipment_leg_id=da.shipment_leg_id and cb.status='confirmed'
  join public.krim_capacity_reservations cr on cr.id=da.reservation_id
   and cr.id=cb.reservation_id and cr.shipment_id=da.shipment_id
   and cr.shipment_leg_id=da.shipment_leg_id and cr.organization_id=da.partner_organization_id
   and cr.status='confirmed'
  where da.shipment_id=p_shipment_id and da.shipment_leg_id=p_shipment_leg_id
   and da.partner_assignment_id=p_partner_assignment_id
   and da.partner_organization_id=p_partner_organization_id and da.status='authorized'
   and private.krim_partner_compliance_is_current(o.id) is true
   and private.krim_partner_capability_covers_shipment_leg(o.id,l.id) is true
   and (l.leg_sequence=1 or exists(
    select 1 from public.krim_shipment_leg_custody_transfers ct
    join public.krim_shipment_legs prev on prev.id=ct.from_leg_id
    where ct.shipment_id=l.shipment_id and ct.to_leg_id=l.id
     and ct.status='accepted' and prev.leg_sequence=l.leg_sequence-1
     and ct.receiving_organization_id=da.partner_organization_id
   ))
 );
$function$;
revoke all on function private.krim_leg_dispatch_authorization_is_current(bigint,bigint,bigint,bigint) from public,anon,authenticated,service_role;

create or replace function public.krim_revoke_leg_dispatch_authorization(p_dispatch_authorization_id bigint,p_reason text)
returns public.krim_shipment_leg_dispatch_authorizations
language plpgsql security definer set search_path=''
as $function$
declare
 v_user uuid:=auth.uid();
 v_auth public.krim_shipment_leg_dispatch_authorizations%rowtype;
 v_result public.krim_shipment_leg_dispatch_authorizations%rowtype;
begin
 if v_user is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if p_dispatch_authorization_id is null or length(btrim(coalesce(p_reason,'')))<3 or length(p_reason)>500 then
  raise exception using errcode='22023',message='A dispatch authorization and a reason of at least three characters are required';
 end if;
 select * into v_auth from public.krim_shipment_leg_dispatch_authorizations where id=p_dispatch_authorization_id for update;
 if not found then raise exception using errcode='P0002',message='Dispatch authorization not found'; end if;
 if not public.krim_has_permission(v_user,v_auth.partner_organization_id,'shipment.dispatch') then
  raise exception using errcode='42501',message='Partner dispatch permission is required';
 end if;
 if v_auth.status='revoked' then return v_auth; end if;
 if exists(select 1 from public.krim_driver_trip_events e join public.krim_driver_assignments da on da.id=e.assignment_id
  where da.partner_assignment_id=v_auth.partner_assignment_id and da.shipment_leg_id=v_auth.shipment_leg_id
   and e.event_type in ('pickup','in_transit')) then
  raise exception using errcode='55000',message='Dispatch authorization cannot be revoked after pickup or transit has been recorded';
 end if;
 update public.krim_shipment_leg_dispatch_authorizations set status='revoked',revoked_at=pg_catalog.now(),
  revoked_by=v_user,revocation_reason=btrim(p_reason) where id=v_auth.id returning * into v_result;
 insert into public.krim_partner_execution_events
 (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,event_type,event_time,notes,metadata,created_by,created_at)
 values(v_auth.partner_assignment_id,v_auth.shipment_id,v_auth.shipment_leg_id,v_auth.partner_organization_id,
  'leg_dispatch_authorization_revoked',pg_catalog.now(),btrim(p_reason),
  pg_catalog.jsonb_build_object('dispatch_authorization_id',v_auth.id),v_user,pg_catalog.now());
 return v_result;
end;
$function$;
revoke all on function public.krim_revoke_leg_dispatch_authorization(bigint,text) from public,anon;
grant execute on function public.krim_revoke_leg_dispatch_authorization(bigint,text) to authenticated;

create or replace function public.krim_driver_record_trip_event(
 p_assignment_id uuid,p_event_type text,p_notes text DEFAULT ''
) RETURNS public.krim_driver_assignments
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
 v_user uuid:=auth.uid();
 v_assignment public.krim_driver_assignments%rowtype;
 v_leg public.krim_shipment_legs%rowtype;
 v_shipment public.krim_shipments%rowtype;
 v_partner_assignment public.krim_shipment_partner_assignments%rowtype;
 v_next_status text;v_tracking_type text;v_partner_event_type text;
 v_event_notes text:=left(btrim(coalesce(p_notes,'')),1000);
 v_is_active_multileg boolean:=false;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required'; END IF;
 IF p_event_type NOT IN ('pickup','in_transit','exception') THEN
  RAISE EXCEPTION USING errcode='22023',message='Unsupported trip event. Delivery completion is recorded only after authorized POD verification.';
 END IF;
 SELECT a.* INTO v_assignment FROM public.krim_driver_assignments a
 WHERE a.id=p_assignment_id AND a.user_id=v_user
  AND EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=a.organization_id AND lower(m.role)='driver' AND lower(m.status)='active')
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING errcode='42501',message='Assignment not found or active driver access is unavailable'; END IF;
 IF p_event_type='pickup' AND v_assignment.status IN ('pickup_complete','in_transit','exception')
  AND EXISTS(SELECT 1 FROM public.krim_driver_trip_events e WHERE e.assignment_id=p_assignment_id AND e.user_id=v_user AND e.event_type='pickup') THEN RETURN v_assignment; END IF;
 IF p_event_type='in_transit' AND v_assignment.status IN ('in_transit','exception')
  AND EXISTS(SELECT 1 FROM public.krim_driver_trip_events e WHERE e.assignment_id=p_assignment_id AND e.user_id=v_user AND e.event_type='in_transit') THEN RETURN v_assignment; END IF;
 IF v_assignment.status IN ('delivered','cancelled','declined') THEN RAISE EXCEPTION USING errcode='55000',message='This assignment is already closed'; END IF;
 IF v_assignment.shipment_id IS NULL OR v_assignment.shipment_leg_id IS NULL OR v_assignment.partner_assignment_id IS NULL THEN
  RAISE EXCEPTION USING errcode='55000',message='Assignment is not linked to an executable shipment leg';
 END IF;
 SELECT pa.* INTO v_partner_assignment FROM public.krim_shipment_partner_assignments pa
 WHERE pa.id=v_assignment.partner_assignment_id AND pa.shipment_id=v_assignment.shipment_id
  AND pa.partner_organization_id=v_assignment.organization_id AND pa.shipment_leg_id=v_assignment.shipment_leg_id FOR UPDATE;
 IF NOT FOUND OR v_partner_assignment.status NOT IN ('accepted','active') THEN
  RAISE EXCEPTION USING errcode='55000',message='Linked partner assignment is missing, mismatched or no longer commercially active';
 END IF;
 SELECT l.* INTO v_leg FROM public.krim_shipment_legs l WHERE l.id=v_assignment.shipment_leg_id AND l.shipment_id=v_assignment.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_leg.status IN ('completed','cancelled','delivered') THEN
  RAISE EXCEPTION USING errcode='55000',message='Linked shipment leg was not found or is already terminal';
 END IF;
 SELECT s.* INTO v_shipment FROM public.krim_shipments s WHERE s.id=v_assignment.shipment_id FOR UPDATE;
 IF NOT FOUND OR v_shipment.status IN ('delivered','closed','cancelled') THEN
  RAISE EXCEPTION USING errcode='55000',message='Shipment is missing or already terminal';
 END IF;
 SELECT EXISTS(SELECT 1 FROM public.krim_shipment_leg_plans p WHERE p.shipment_id=v_shipment.id AND p.status='active' AND p.total_legs>1)
 INTO v_is_active_multileg;
 IF p_event_type IN ('pickup','in_transit') AND v_is_active_multileg THEN
  IF NOT private.krim_leg_dispatch_authorization_is_current(v_shipment.id,v_leg.id,v_partner_assignment.id,v_assignment.organization_id) THEN
   RAISE EXCEPTION USING errcode='55000',message='Current exact-leg dispatch authorization, partner compliance, capability, capacity and custody are required';
  END IF;
  IF (SELECT tm.code FROM public.krim_transport_modes tm WHERE tm.id=v_leg.transport_mode_id)<>'ROAD' THEN
   RAISE EXCEPTION USING errcode='55000',message='Driver pickup and transit events are restricted to ROAD legs';
  END IF;
 END IF;
 IF p_event_type='pickup' THEN
  IF v_assignment.status<>'accepted' OR v_assignment.accepted_at IS NULL OR v_assignment.accepted_by IS DISTINCT FROM v_user THEN
   RAISE EXCEPTION USING errcode='55000',message='Accept the driver assignment before recording pickup';
  END IF;
  IF (NOT v_is_active_multileg AND v_shipment.status NOT IN ('dispatched','in_transit')) OR v_leg.status NOT IN ('assigned','in_transit') THEN
   RAISE EXCEPTION USING errcode='55000',message='Shipment must be dispatched and the linked leg assigned before pickup can be recorded';
  END IF;
  v_next_status:='pickup_complete';v_tracking_type:='picked_up';v_partner_event_type:='picked_up';
 ELSIF p_event_type='in_transit' THEN
  IF v_assignment.status<>'pickup_complete' THEN RAISE EXCEPTION USING errcode='55000',message='Record pickup before transit'; END IF;
  IF (NOT v_is_active_multileg AND v_shipment.status NOT IN ('dispatched','in_transit')) OR v_leg.status NOT IN ('assigned','in_transit') THEN
   RAISE EXCEPTION USING errcode='55000',message='Shipment must be dispatched and the linked leg must be executable before transit can be recorded';
  END IF;
  v_next_status:='in_transit';v_tracking_type:='in_transit';v_partner_event_type:='in_transit';
 ELSE
  IF length(v_event_notes)<3 THEN RAISE EXCEPTION USING errcode='22023',message='Please provide details for an exception'; END IF;
  IF v_assignment.status NOT IN ('accepted','pickup_complete','in_transit','exception') THEN RAISE EXCEPTION USING errcode='55000',message='Assignment is not active for exception reporting'; END IF;
  v_next_status:='exception';v_tracking_type:='exception';v_partner_event_type:='exception_reported';
 END IF;
 INSERT INTO public.krim_driver_trip_events(assignment_id,user_id,event_type,notes) VALUES(p_assignment_id,v_user,p_event_type,v_event_notes);
 UPDATE public.krim_driver_assignments SET status=v_next_status,updated_at=pg_catalog.now() WHERE id=p_assignment_id RETURNING * INTO v_assignment;
 IF p_event_type='in_transit' THEN
  UPDATE public.krim_shipment_legs SET status='in_transit',actual_departure=coalesce(actual_departure,pg_catalog.now()),updated_at=pg_catalog.now() WHERE id=v_leg.id;
  IF NOT v_is_active_multileg THEN
   UPDATE public.krim_shipments SET status=CASE WHEN status='dispatched' THEN 'in_transit' ELSE status END,updated_at=pg_catalog.now() WHERE id=v_shipment.id;
  END IF;
 END IF;
 INSERT INTO public.krim_tracking_events(shipment_id,shipment_leg_id,event_type,event_time,source_type,source_reference,metadata,partner_organization_id,assignment_id,created_at)
 VALUES(v_shipment.id,v_leg.id,v_tracking_type,pg_catalog.now(),'driver',p_assignment_id::text,
  pg_catalog.jsonb_build_object('driver_user_id',v_user,'driver_assignment_id',p_assignment_id,'partner_assignment_id',v_assignment.partner_assignment_id,
   'driver_event_type',p_event_type,'notes',v_event_notes,'leg_dispatch_authorization_required',v_is_active_multileg),
  v_assignment.organization_id,v_assignment.partner_assignment_id,pg_catalog.now());
 INSERT INTO public.krim_partner_execution_events(assignment_id,shipment_id,shipment_leg_id,partner_organization_id,event_type,event_time,notes,metadata,created_by,created_at)
 VALUES(v_assignment.partner_assignment_id,v_shipment.id,v_leg.id,v_assignment.organization_id,v_partner_event_type,pg_catalog.now(),
  nullif(v_event_notes,''),pg_catalog.jsonb_build_object('driver_assignment_id',p_assignment_id,'driver_user_id',v_user,
  'source','driver_trip_event','leg_dispatch_authorization_required',v_is_active_multileg),v_user,pg_catalog.now());
 RETURN v_assignment;
END;
$function$;