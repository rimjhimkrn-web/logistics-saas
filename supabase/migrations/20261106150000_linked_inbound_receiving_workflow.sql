CREATE OR REPLACE FUNCTION public.krim_warehouse_list_assigned_shipment_legs(p_organization_id bigint,p_facility_id uuid)
RETURNS TABLE(shipment_id bigint, shipment_leg_id bigint, shipment_number text, leg_sequence integer, leg_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode='28000'; END IF;
 IF NOT private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) THEN
  RAISE EXCEPTION 'Verified warehouse facility access required' USING errcode='42501';
 END IF;
 RETURN QUERY
 SELECT l.shipment_id,l.id,s.shipment_number,l.leg_sequence,l.status
 FROM public.krim_shipment_legs l JOIN public.krim_shipments s ON s.id=l.shipment_id
 WHERE l.partner_organization_id=p_organization_id
 AND l.status IN ('assigned','planned','in_transit','arrived')
 ORDER BY s.created_at DESC,l.leg_sequence;
END; $$;
REVOKE ALL ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_inbound_task(
 p_organization_id bigint,p_facility_id uuid,p_shipment_id bigint,p_shipment_leg_id bigint,
 p_reference_code text,p_quality_status text,p_notes text,p_idempotency_key uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_user uuid:=auth.uid(); v_task public.krim_warehouse_tasks%rowtype;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode='28000'; END IF;
 IF NOT private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) THEN
  RAISE EXCEPTION 'Verified warehouse facility access and partner.manage permission required' USING errcode='42501';
 END IF;
 IF p_shipment_id IS NULL OR p_shipment_leg_id IS NULL OR p_idempotency_key IS NULL
  OR nullif(btrim(p_reference_code),'') IS NULL OR length(btrim(p_reference_code))>120 THEN
  RAISE EXCEPTION 'Shipment, shipment leg, receipt reference and idempotency key are required' USING errcode='22023';
 END IF;
 IF coalesce(p_quality_status,'pending') NOT IN ('pending','hold','rejected') THEN
  RAISE EXCEPTION 'Inbound receipt cannot release inventory' USING errcode='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.krim_shipment_legs l WHERE l.id=p_shipment_leg_id
  AND l.shipment_id=p_shipment_id AND l.partner_organization_id=p_organization_id
  AND l.status IN ('assigned','planned','in_transit','arrived')) THEN
  RAISE EXCEPTION 'Shipment leg is not assigned to this warehouse organisation or is not operational' USING errcode='42501';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('krim_wh_task:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 SELECT * INTO v_task FROM public.krim_warehouse_tasks
 WHERE organization_id=p_organization_id AND idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'inbound_receiving'
   OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.quality_status<>coalesce(p_quality_status,'pending')
   OR v_task.notes<>left(coalesce(p_notes,''),4000) THEN
   RAISE EXCEPTION 'Idempotency key was already used for a different warehouse task' USING errcode='23505';
  END IF;
  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;
 INSERT INTO public.krim_warehouse_receipts(organization_id,facility_id,shipment_id,shipment_leg_id,receipt_reference,status,notes)
 VALUES(p_organization_id,p_facility_id,p_shipment_id,p_shipment_leg_id,btrim(p_reference_code),'expected',left(coalesce(p_notes,''),4000));
 INSERT INTO public.krim_warehouse_tasks(organization_id,facility_id,task_type,reference_code,quality_status,severity,notes,idempotency_key,created_by,shipment_id,shipment_leg_id)
 VALUES(p_organization_id,p_facility_id,'inbound_receiving',btrim(p_reference_code),coalesce(p_quality_status,'pending'),'normal',
  left(coalesce(p_notes,''),4000),p_idempotency_key,v_user,p_shipment_id,p_shipment_leg_id) RETURNING * INTO v_task;
 INSERT INTO public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id)
 VALUES(v_task.id,p_organization_id,p_facility_id,'task.created','open',
  jsonb_build_object('task_type','inbound_receiving','reference_code',p_reference_code,'shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id),v_user);
 RETURN jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
END; $$;
REVOKE ALL ON FUNCTION public.krim_warehouse_create_linked_inbound_task(bigint,uuid,bigint,bigint,text,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_inbound_task(bigint,uuid,bigint,bigint,text,text,text,uuid) TO authenticated;
