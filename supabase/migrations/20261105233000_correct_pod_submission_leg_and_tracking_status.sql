-- A submitted POD is not proof of completed delivery.
-- Bind the POD to the exact accepted partner-assignment leg and expose only a pod_submitted tracking event.
create or replace function public.krim_internal_submit_delivery_pod(
 p_assignment_id bigint,
 p_received_by_name text default null,
 p_received_by_role text default null,
 p_signature_reference text default null,
 p_evidence_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
 v_assignment public.krim_shipment_partner_assignments%rowtype;
 v_shipment public.krim_shipments%rowtype;
 v_leg public.krim_shipment_legs%rowtype;
 v_pod public.krim_pod_records%rowtype;
begin
 select * into v_assignment
 from public.krim_shipment_partner_assignments
 where id=p_assignment_id
 for update;
 if not found then raise exception 'Assignment % not found',p_assignment_id; end if;

 select * into v_shipment
 from public.krim_shipments
 where id=v_assignment.shipment_id
 for update;
 if not found then raise exception 'Shipment % not found',v_assignment.shipment_id; end if;

 if v_shipment.status='delivered' then
   return jsonb_build_object('submitted',true,'idempotent',true,'shipment_id',v_shipment.id,'next_step','close');
 end if;
 if v_shipment.status <> 'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery POD; current status %',v_shipment.id,v_shipment.status;
 end if;
 if v_assignment.status not in ('active','accepted') then
   raise exception 'Assignment % is not active/accepted',v_assignment.id;
 end if;

 if v_assignment.shipment_leg_id is null then
   raise exception 'Partner assignment % has no shipment leg; POD cannot be submitted',v_assignment.id;
 end if;
 select * into v_leg
 from public.krim_shipment_legs
 where id=v_assignment.shipment_leg_id
   and shipment_id=v_shipment.id
 for update;
 if not found then
   raise exception 'Assigned shipment leg % does not belong to shipment %',v_assignment.shipment_leg_id,v_shipment.id;
 end if;
 if p_received_by_name is null or btrim(p_received_by_name)='' then
   raise exception 'Receiver name is required';
 end if;

 select * into v_pod
 from public.krim_pod_records
 where assignment_id=v_assignment.id
   and shipment_leg_id=v_leg.id
   and pod_type='delivery'
   and status in ('submitted','under_review','verified')
 order by id desc
 limit 1
 for update;

 if found then
   return jsonb_build_object(
     'submitted',true,'idempotent',true,'pod_id',v_pod.id,
     'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,
     'status',v_pod.status,
     'next_step',case when v_pod.status='verified' then 'delivery_authorization' else 'verification' end
   );
 end if;

 insert into public.krim_pod_records
 (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,pod_type,status,
  delivered_at,received_by_name,received_by_role,signature_reference,evidence_metadata,
  submitted_at,created_at,updated_at)
 values
 (v_assignment.id,v_shipment.id,v_leg.id,v_assignment.partner_organization_id,'delivery','submitted',
  now(),btrim(p_received_by_name),nullif(btrim(p_received_by_role),''),nullif(btrim(p_signature_reference),''),
  coalesce(p_evidence_metadata,'{}'::jsonb),now(),now(),now())
 returning * into v_pod;

 insert into public.krim_partner_execution_events
 (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,
  metadata,partner_organization_id,assignment_id,created_at)
 values
 (v_shipment.id,v_leg.id,'pod_submitted',now(),v_leg.destination_location_id,'system',
  'krim_pod_submission',jsonb_build_object('pod_id',v_pod.id),v_assignment.partner_organization_id,v_assignment.id,now());

 insert into public.krim_tracking_events
 (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,metadata,created_at)
 values
 (v_shipment.id,v_leg.id,'pod_submitted',now(),v_leg.destination_location_id,'system',
  'krim_pod_submission',jsonb_build_object('pod_id',v_pod.id,'pending_verification',true),now());

 insert into public.krim_audit_events
 (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
 values
 (null,v_shipment.customer_organization_id,'shipment.pod_submitted','shipment',v_shipment.id::text,'operations',
  jsonb_build_object('assignment_id',v_assignment.id,'shipment_leg_id',v_leg.id,'pod_id',v_pod.id),
  jsonb_build_object('status','in_transit'),jsonb_build_object('status','pod_submitted'),now());

 return jsonb_build_object(
  'submitted',true,'idempotent',false,'pod_id',v_pod.id,'shipment_id',v_shipment.id,
  'shipment_leg_id',v_leg.id,'status','submitted','next_step','verification'
 );
end;
$function$;
