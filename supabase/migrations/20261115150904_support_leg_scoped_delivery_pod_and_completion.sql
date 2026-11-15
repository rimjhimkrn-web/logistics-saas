CREATE OR REPLACE FUNCTION public.krim_internal_submit_delivery_pod(p_assignment_id bigint, p_received_by_name text DEFAULT NULL::text, p_received_by_role text DEFAULT NULL::text, p_signature_reference text DEFAULT NULL::text, p_evidence_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_assignment public.krim_shipment_partner_assignments%rowtype;
 v_shipment public.krim_shipments%rowtype;
 v_leg public.krim_shipment_legs%rowtype;
 v_pod public.krim_pod_records%rowtype;
 v_plan public.krim_shipment_leg_plans%rowtype;
 v_is_active_multileg boolean:=false;
begin
 if p_assignment_id is null or nullif(pg_catalog.btrim(p_received_by_name),'') is null then
  raise exception using errcode='22023',message='Assignment and recipient name are required';
 end if;
 if pg_catalog.length(pg_catalog.btrim(p_received_by_name))>200
  or pg_catalog.length(coalesce(p_received_by_role,''))>120
  or pg_catalog.length(coalesce(p_signature_reference,''))>240 then
  raise exception using errcode='22023',message='POD recipient fields exceed permitted lengths';
 end if;
 if p_evidence_metadata is null or pg_catalog.jsonb_typeof(p_evidence_metadata)<>'object' then
  raise exception using errcode='22023',message='POD evidence metadata must be a JSON object';
 end if;
 select * into v_assignment from public.krim_shipment_partner_assignments
 where id=p_assignment_id for update;
 if not found then raise exception 'Assignment % not found',p_assignment_id; end if;
 select * into v_shipment from public.krim_shipments
 where id=v_assignment.shipment_id for update;
 if not found then raise exception 'Shipment % not found',v_assignment.shipment_id; end if;
 if v_assignment.shipment_leg_id is null then raise exception 'Partner assignment % has no shipment leg',v_assignment.id; end if;
 select * into v_leg from public.krim_shipment_legs
 where id=v_assignment.shipment_leg_id and shipment_id=v_shipment.id
  and partner_organization_id=v_assignment.partner_organization_id for update;
 if not found then raise exception 'Assigned shipment leg is missing or does not match shipment and partner'; end if;
 select * into v_plan from public.krim_shipment_leg_plans
 where shipment_id=v_shipment.id and status='active' and total_legs>1
 order by plan_version desc limit 1;
 v_is_active_multileg:=found;
 select * into v_pod from public.krim_pod_records
 where assignment_id=v_assignment.id and shipment_id=v_shipment.id
  and shipment_leg_id=v_leg.id and pod_type='delivery'
  and status in('submitted','under_review','verified')
 order by id desc limit 1 for update;
 if found then
  if v_pod.received_by_name is distinct from pg_catalog.btrim(p_received_by_name)
   or v_pod.received_by_role is distinct from nullif(pg_catalog.btrim(p_received_by_role),'')
   or v_pod.signature_reference is distinct from nullif(pg_catalog.btrim(p_signature_reference),'')
   or v_pod.evidence_metadata is distinct from p_evidence_metadata then
   raise exception using errcode='23505',message='A delivery POD already exists for this assignment and leg with a different payload; conflicting retry rejected';
  end if;
  return pg_catalog.jsonb_build_object('submitted',true,'idempotent',true,'pod_id',v_pod.id,
   'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'status',v_pod.status,
   'next_step',case when v_pod.status='verified' then 'delivery_authorization' else 'verification' end);
 end if;
 if v_is_active_multileg then
  if v_shipment.status not in('assigned','in_transit') then
   raise exception using errcode='55000',message='Multi-leg shipment must remain in an active shipment lifecycle before leg delivery evidence can be submitted';
  end if;
  if v_leg.status<>'in_transit' then
   raise exception using errcode='55000',message='The exact shipment leg must be in transit before POD submission';
  end if;
  if not exists(select 1 from public.krim_shipment_leg_plan_items i
   where i.plan_id=v_plan.id and i.id=v_leg.leg_plan_item_id
    and i.leg_sequence=v_leg.leg_sequence and i.origin_location_id=v_leg.origin_location_id
    and i.destination_location_id=v_leg.destination_location_id
    and i.transport_mode_id=v_leg.transport_mode_id
    and i.partner_organization_id=v_assignment.partner_organization_id
    and i.assignment_id=v_assignment.id) then
   raise exception using errcode='55000',message='POD leg, partner assignment and active route-plan item do not match';
  end if;
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery POD; current status %',v_shipment.id,v_shipment.status;
  end if;
 end if;
 if v_assignment.status not in('active','accepted') then
  raise exception 'Assignment % is not active/accepted',v_assignment.id;
 end if;
 if p_evidence_metadata->>'driver_assignment_id' is null
  or pg_catalog.jsonb_typeof(p_evidence_metadata->'driver_evidence')<>'array'
  or pg_catalog.jsonb_array_length(p_evidence_metadata->'driver_evidence')<1 then
  raise exception using errcode='55000',message='At least one assigned-driver evidence record is required';
 end if;
 insert into public.krim_pod_records
 (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,pod_type,status,
  delivered_at,received_by_name,received_by_role,signature_reference,evidence_metadata,
  submitted_at,created_at,updated_at)
 values(v_assignment.id,v_shipment.id,v_leg.id,v_assignment.partner_organization_id,'delivery','submitted',
  pg_catalog.now(),pg_catalog.btrim(p_received_by_name),nullif(pg_catalog.btrim(p_received_by_role),''),
  nullif(pg_catalog.btrim(p_signature_reference),''),p_evidence_metadata,
  pg_catalog.now(),pg_catalog.now(),pg_catalog.now())
 returning * into v_pod;
 insert into public.krim_partner_execution_events
 (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,metadata,
  partner_organization_id,assignment_id,created_at)
 values(v_shipment.id,v_leg.id,'pod_submitted',pg_catalog.now(),v_leg.destination_location_id,'system',
  'krim_pod_submission',pg_catalog.jsonb_build_object('pod_id',v_pod.id,'multi_leg',v_is_active_multileg),
  v_assignment.partner_organization_id,v_assignment.id,pg_catalog.now());
 insert into public.krim_tracking_events
 (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,metadata,created_at)
 values(v_shipment.id,v_leg.id,'pod_submitted',pg_catalog.now(),v_leg.destination_location_id,'system',
  'krim_pod_submission',pg_catalog.jsonb_build_object('pod_id',v_pod.id,'pending_verification',true,
   'multi_leg',v_is_active_multileg),pg_catalog.now());
 insert into public.krim_audit_events
 (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
 values(null,v_shipment.customer_organization_id,'shipment.pod_submitted','shipment',v_shipment.id::text,'operations',
  pg_catalog.jsonb_build_object('assignment_id',v_assignment.id,'shipment_leg_id',v_leg.id,
   'pod_id',v_pod.id,'multi_leg',v_is_active_multileg),
  pg_catalog.jsonb_build_object('shipment_status',v_shipment.status,'leg_status',v_leg.status),
  pg_catalog.jsonb_build_object('pod_status','submitted'),pg_catalog.now());
 return pg_catalog.jsonb_build_object('submitted',true,'idempotent',false,'pod_id',v_pod.id,
  'shipment_id',v_shipment.id,'shipment_leg_id',v_leg.id,'status','submitted','next_step','verification');
end;
$function$
;

CREATE OR REPLACE FUNCTION public.krim_internal_authorize_delivery(p_pod_id bigint, p_verifier_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_pod public.krim_pod_records%rowtype;
 v_assignment public.krim_shipment_partner_assignments%rowtype;
 v_shipment public.krim_shipments%rowtype;
 v_leg public.krim_shipment_legs%rowtype;
 v_plan public.krim_shipment_leg_plans%rowtype;
 v_is_active_multileg boolean:=false;
 v_final_leg boolean:=false;
 v_new_shipment_status text;
 v_plan_item_count integer:=0;
 v_materialized_leg_count integer:=0;
begin
 select * into v_pod from public.krim_pod_records where id=p_pod_id for update;
 if not found then raise exception 'POD % not found',p_pod_id; end if;
 if v_pod.status<>'verified' then raise exception 'POD % must be verified; current status %',p_pod_id,v_pod.status; end if;
 if p_verifier_user_id is null then raise exception 'Verifier identity is required'; end if;
 select * into v_assignment from public.krim_shipment_partner_assignments where id=v_pod.assignment_id for update;
 if not found then raise exception 'Partner assignment % not found',v_pod.assignment_id; end if;
 if v_assignment.shipment_id is distinct from v_pod.shipment_id
  or v_assignment.shipment_leg_id is distinct from v_pod.shipment_leg_id
  or v_assignment.partner_organization_id is distinct from v_pod.partner_organization_id then
  raise exception 'POD assignment, shipment, leg and partner organization linkage is inconsistent';
 end if;
 select * into v_shipment from public.krim_shipments where id=v_pod.shipment_id for update;
 if not found then raise exception 'Shipment % not found',v_pod.shipment_id; end if;
 select * into v_leg from public.krim_shipment_legs
 where id=v_pod.shipment_leg_id and shipment_id=v_shipment.id
  and partner_organization_id=v_assignment.partner_organization_id for update;
 if not found then raise exception 'POD shipment leg is missing or does not match shipment and assigned partner'; end if;
 select * into v_plan from public.krim_shipment_leg_plans
 where shipment_id=v_shipment.id and status='active' and total_legs>1
 order by plan_version desc limit 1;
 v_is_active_multileg:=found;
 if v_shipment.status='delivered' then
  if v_leg.status in('completed','delivered') then
   return pg_catalog.jsonb_build_object('delivered',true,'idempotent',true,'shipment_id',v_shipment.id,
    'pod_id',v_pod.id,'shipment_leg_id',v_leg.id,'next_step','execution_completed');
  end if;
  raise exception using errcode='55000',message='Shipment is already delivered but this leg is not complete; manual reconciliation is required';
 end if;
 if v_assignment.status not in('active','accepted') then
  raise exception 'Assignment % is not active/accepted',v_assignment.id;
 end if;
 if v_is_active_multileg then
  if v_shipment.status not in('assigned','in_transit') then
   raise exception 'Multi-leg shipment is not in an active shipment lifecycle; current status %',v_shipment.status;
  end if;
  if v_leg.status<>'in_transit' then
   raise exception 'Exact shipment leg must be in_transit before delivery authorization; current status %',v_leg.status;
  end if;
  if not exists(select 1 from public.krim_shipment_leg_plan_items i
   where i.plan_id=v_plan.id and i.id=v_leg.leg_plan_item_id
    and i.leg_sequence=v_leg.leg_sequence and i.origin_location_id=v_leg.origin_location_id
    and i.destination_location_id=v_leg.destination_location_id
    and i.transport_mode_id=v_leg.transport_mode_id
    and i.partner_organization_id=v_assignment.partner_organization_id
    and i.assignment_id=v_assignment.id) then
   raise exception 'Delivery leg, partner assignment and active route-plan item do not match';
  end if;
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery authorization; current status %',v_shipment.id,v_shipment.status;
  end if;
 end if;
 if v_is_active_multileg then
  update public.krim_shipment_legs set status='completed',
   actual_arrival=coalesce(actual_arrival,pg_catalog.now()),updated_at=pg_catalog.now()
  where id=v_leg.id;
 else
  update public.krim_shipment_legs set status='delivered',
   actual_arrival=coalesce(actual_arrival,pg_catalog.now()),updated_at=pg_catalog.now()
  where id=v_leg.id;
 end if;
 update public.krim_shipment_partner_assignments set status='completed',updated_at=pg_catalog.now()
 where id=v_assignment.id;
 if v_is_active_multileg then
  select count(*)::integer into v_plan_item_count
  from public.krim_shipment_leg_plan_items where plan_id=v_plan.id;
  select count(*)::integer into v_materialized_leg_count
  from public.krim_shipment_legs l
  join public.krim_shipment_leg_plan_items i on i.id=l.leg_plan_item_id and i.plan_id=v_plan.id
  where l.shipment_id=v_shipment.id and l.status in('completed','delivered');
  select v_plan_item_count=v_plan.total_legs
    and v_materialized_leg_count=v_plan.total_legs
    and not exists(select 1 from public.krim_shipment_legs l
      where l.shipment_id=v_shipment.id and l.status not in('completed','delivered'))
   into v_final_leg;
  v_new_shipment_status:=case when v_final_leg then 'delivered' else v_shipment.status end;
 else
  select not exists(select 1 from public.krim_shipment_legs l
   where l.shipment_id=v_shipment.id and l.id<>v_leg.id
    and l.status not in('delivered','completed','cancelled')) into v_final_leg;
  v_new_shipment_status:=case when v_final_leg then 'delivered' else 'in_transit' end;
 end if;
 if v_final_leg then
  update public.krim_shipments set status='delivered',
   last_known_location_id=v_leg.destination_location_id,
   actual_delivery_at=coalesce(actual_delivery_at,pg_catalog.now()),updated_at=pg_catalog.now()
  where id=v_shipment.id;
 elsif not v_is_active_multileg then
  update public.krim_shipments set last_known_location_id=v_leg.destination_location_id,updated_at=pg_catalog.now()
  where id=v_shipment.id;
 end if;
 insert into public.krim_tracking_events
 (shipment_id,shipment_leg_id,event_type,event_time,location_id,source_type,source_reference,metadata,created_at)
 values(v_shipment.id,v_leg.id,case when v_final_leg then 'delivered' else 'leg_delivered' end,
  pg_catalog.now(),v_leg.destination_location_id,'system','krim_delivery_authorization',
  pg_catalog.jsonb_build_object('pod_id',v_pod.id,'verified_by',p_verifier_user_id,
   'shipment_completed',v_final_leg,'multi_leg',v_is_active_multileg),pg_catalog.now());
 insert into public.krim_partner_execution_events
 (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,event_type,event_time,location_id,
  evidence_reference,metadata,created_by,created_at)
 values(v_assignment.id,v_shipment.id,v_leg.id,v_assignment.partner_organization_id,'delivered',
  pg_catalog.now(),v_leg.destination_location_id,v_pod.document_record_id::text,
  pg_catalog.jsonb_build_object('pod_id',v_pod.id,'verified_by',p_verifier_user_id,
   'shipment_completed',v_final_leg,'multi_leg',v_is_active_multileg),p_verifier_user_id,pg_catalog.now());
 if v_final_leg then
  insert into public.krim_partner_execution_events
  (assignment_id,shipment_id,shipment_leg_id,partner_organization_id,event_type,event_time,location_id,
   evidence_reference,metadata,created_by,created_at)
  values(v_assignment.id,v_shipment.id,v_leg.id,v_assignment.partner_organization_id,'execution_completed',
   pg_catalog.now(),v_leg.destination_location_id,v_pod.document_record_id::text,
   pg_catalog.jsonb_build_object('pod_id',v_pod.id,'multi_leg',v_is_active_multileg),
   p_verifier_user_id,pg_catalog.now());
 end if;
 insert into public.krim_audit_events
 (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state,created_at)
 values(p_verifier_user_id,v_shipment.customer_organization_id,
  case when v_final_leg then 'shipment.delivered' else 'shipment.leg_delivered' end,
  'shipment',v_shipment.id::text,'operations',
  pg_catalog.jsonb_build_object('pod_id',v_pod.id,'assignment_id',v_assignment.id,
   'shipment_leg_id',v_leg.id,'final_leg',v_final_leg,'multi_leg',v_is_active_multileg),
  pg_catalog.jsonb_build_object('shipment_status',v_shipment.status,'leg_status',v_leg.status),
  pg_catalog.jsonb_build_object('shipment_status',v_new_shipment_status,
   'leg_status',case when v_is_active_multileg then 'completed' else 'delivered' end),pg_catalog.now());
 return pg_catalog.jsonb_build_object('delivered',v_final_leg,'leg_delivered',true,
  'idempotent',false,'shipment_id',v_shipment.id,'shipment_number',v_shipment.shipment_number,
  'pod_id',v_pod.id,'assignment_id',v_assignment.id,'shipment_leg_id',v_leg.id,
  'status',v_new_shipment_status,'assignment_status','completed',
  'next_step',case when v_final_leg then 'execution_completed' else 'continue_remaining_legs' end,
  'multi_leg',v_is_active_multileg);
end;
$function$
;
