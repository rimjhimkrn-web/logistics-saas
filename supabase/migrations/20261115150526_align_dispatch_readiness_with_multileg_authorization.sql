create or replace function public.krim_operations_dispatch_readiness()
returns table(
 assignment_id bigint, shipment_id bigint, shipment_number text, shipment_status text,
 shipment_leg_id bigint, leg_sequence integer, leg_status text, assignment_status text,
 partner_organization_id bigint, handover_complete boolean, eligible_driver_count integer,
 readiness_status text, blockers text[]
)
language sql
stable
security definer
set search_path=''
as $function$
with scoped as (
 select a.id assignment_id,a.shipment_id,s.shipment_number,s.status shipment_status,
  a.shipment_leg_id,l.leg_sequence,l.status leg_status,l.assignment_status,
  a.partner_organization_id,a.status partner_assignment_status,
  o.status org_status,o.partner_account_mode,o.partner_verification_status,
  o.partner_lifecycle_status,o.partner_compliance_status,
  (select tm.code from public.krim_transport_modes tm where tm.id=l.transport_mode_id) mode_code,
  s.total_weight_kg,
  exists(select 1 from public.krim_shipment_leg_plans p
   where p.shipment_id=s.id and p.status='active' and p.total_legs>1) is_active_multileg,
  exists(select 1 from public.krim_shipment_leg_plans p
   join public.krim_shipment_leg_plan_items i on i.plan_id=p.id
   where p.shipment_id=s.id and p.status='active' and p.total_legs>1
    and i.id=l.leg_plan_item_id and i.leg_sequence=l.leg_sequence
    and i.origin_location_id=l.origin_location_id
    and i.destination_location_id=l.destination_location_id
    and i.transport_mode_id=l.transport_mode_id
    and i.partner_organization_id=a.partner_organization_id and i.assignment_id=a.id) exact_active_plan_item
 from public.krim_shipment_partner_assignments a
 join public.krim_shipments s on s.id=a.shipment_id
 join public.krim_shipment_legs l on l.id=a.shipment_leg_id and l.shipment_id=a.shipment_id
 join public.krim_organizations o on o.id=a.partner_organization_id
 where a.status in('accepted','active')
  and (auth.uid() is not null or auth.jwt()->>'role'='service_role')
  and (auth.jwt()->>'role'='service_role' or public.krim_has_permission(auth.uid(),a.partner_organization_id,'shipment.dispatch'))
), checks as (
 select x.*,
  exists(select 1 from public.krim_warehouse_tasks h
   where h.organization_id=x.partner_organization_id and h.shipment_id=x.shipment_id
    and h.shipment_leg_id=x.shipment_leg_id and h.task_type='dispatch_handover' and h.status='completed') handover_ok,
  (select count(distinct dp.user_id)::integer
   from public.krim_driver_profiles dp
   join public.krim_organization_members m on m.user_id=dp.user_id
    and m.organization_id=dp.organization_id and lower(m.role)='driver' and lower(m.status)='active'
   join public.krim_vehicle_driver_bindings b on b.driver_user_id=dp.user_id
    and b.organization_id=x.partner_organization_id and b.status='active'
   join public.krim_vehicles v on v.id=b.vehicle_id and v.organization_id=x.partner_organization_id
    and v.verification_status='verified' and v.operational_status='active'
   where dp.organization_id=x.partner_organization_id
    and dp.verification_status in('verified','approved')
    and nullif(btrim(dp.licence_number),'') is not null
    and exists(select 1 from public.krim_driver_verification_documents d
     where d.profile_id=dp.id and d.document_type='licence_front' and d.review_status='accepted')
    and exists(select 1 from public.krim_driver_verification_documents d
     where d.profile_id=dp.id and d.document_type='licence_back' and d.review_status='accepted')
    and x.mode_code='ROAD' and x.total_weight_kg>0 and v.payload_capacity>0
    and lower(btrim(coalesce(v.payload_unit,''))) in('kg','kilogram','kilograms','t','ton','tonne','tonnes','mt')
    and v.payload_capacity*case when lower(btrim(v.payload_unit)) in('t','ton','tonne','tonnes','mt') then 1000 else 1 end >= x.total_weight_kg
    and exists(select 1 from public.krim_vehicle_document_requirements r
     where r.registration_country_code=v.registration_country_code
      and lower(r.vehicle_category)=lower(v.vehicle_category) and r.is_required=true)
    and not exists(select 1 from public.krim_vehicle_document_requirements r
     where r.registration_country_code=v.registration_country_code
      and lower(r.vehicle_category)=lower(v.vehicle_category) and r.is_required=true
      and not exists(select 1 from public.krim_vehicle_documents vd
       where vd.vehicle_id=v.id and vd.document_type=r.document_type
        and vd.review_status='approved' and (vd.expires_at is null or vd.expires_at>=current_date)))
    and not exists(select 1 from public.krim_driver_assignments da
     where da.user_id=dp.user_id
      and da.status in('assigned','accepted','pickup_complete','in_transit','exception')
      and da.partner_assignment_id is distinct from x.assignment_id)
  ) compatible_drivers
 from scoped x
), results as (
 select c.*,
  array_remove(array[
   case when (not c.is_active_multileg and c.shipment_status<>'assigned')
     or (c.is_active_multileg and c.shipment_status not in('assigned','in_transit'))
     then 'Shipment lifecycle status is not eligible for this dispatch path' end,
   case when c.leg_status<>'assigned' or c.partner_assignment_status not in('accepted','active')
     then 'Shipment leg or partner assignment is not in an executable state' end,
   case when c.org_status<>'active' or c.partner_account_mode<>'registered_business'
     or c.partner_verification_status not in('verified','approved')
     or c.partner_lifecycle_status not in('active','verified')
     or c.partner_compliance_status not in('clear','compliant','approved','verified','not_required','not_applicable')
     or private.krim_partner_compliance_is_current(c.partner_organization_id) is not true
     then 'Partner verification or current compliance is incomplete' end,
   case when not c.handover_ok then 'Completed warehouse dispatch handover is missing' end,
   case when c.mode_code<>'ROAD' then 'This driver and road-vehicle workflow only supports ROAD legs' end,
   case when c.total_weight_kg is null or c.total_weight_kg<=0 then 'Shipment weight is missing or invalid' end,
   case when c.compatible_drivers=0 then 'No verified, available driver with an eligible vehicle and sufficient payload is available' end,
   case when c.is_active_multileg and not c.exact_active_plan_item
     then 'The leg is not an exact item in the active multi-leg route plan' end,
   case when c.is_active_multileg and not exists(
     select 1 from public.krim_driver_assignments da
     where da.partner_assignment_id=c.assignment_id and da.shipment_id=c.shipment_id
      and da.shipment_leg_id=c.shipment_leg_id and da.organization_id=c.partner_organization_id
      and da.status='accepted' and da.accepted_at is not null and da.accepted_by=da.user_id
   ) then 'An accepted driver assignment bound to this exact leg and partner is required' end,
   case when c.is_active_multileg and not private.krim_leg_dispatch_authorization_is_current(
     c.shipment_id,c.shipment_leg_id,c.assignment_id,c.partner_organization_id)
     then 'Current exact-leg dispatch authorization, confirmed physical capacity and accepted custody are required' end,
   case when c.is_active_multileg is false
      and private.krim_partner_capability_covers_shipment(c.partner_organization_id,c.shipment_id) is not true
     then 'Verified route capability does not cover this shipment' end,
   case when c.is_active_multileg and c.mode_code<>'ROAD'
     then 'Non-road dispatch is held pending mode-specific resource and execution controls' end
  ],null) blockers
 from checks c
)
select r.assignment_id,r.shipment_id,r.shipment_number,r.shipment_status,
 r.shipment_leg_id,r.leg_sequence,r.leg_status,r.partner_assignment_status,
 r.partner_organization_id,r.handover_ok,r.compatible_drivers,
 case when cardinality(r.blockers)=0 then 'ready_for_authorized_review' else 'blocked' end,
 r.blockers
from results r
order by r.shipment_id,r.leg_sequence,r.assignment_id;
$function$;