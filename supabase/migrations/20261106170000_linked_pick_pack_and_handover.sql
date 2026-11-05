CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_pick_task(
 p_organization_id bigint,p_facility_id uuid,p_shipment_id bigint,p_shipment_leg_id bigint,
 p_reference_code text,p_sku text,p_item_description text,p_lot_code text,p_quantity numeric,
 p_unit_code text,p_source_location text,p_notes text,p_idempotency_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid(); v_task public.krim_warehouse_tasks%rowtype;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode='28000'; END IF;
 IF NOT private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) THEN RAISE EXCEPTION 'Verified warehouse facility access and partner.manage permission required' USING errcode='42501'; END IF;
 IF p_shipment_id IS NULL OR p_shipment_leg_id IS NULL OR p_idempotency_key IS NULL OR nullif(btrim(p_reference_code),'') IS NULL OR length(btrim(p_reference_code))>120 OR nullif(btrim(p_sku),'') IS NULL OR p_quantity IS NULL OR p_quantity<=0 OR p_quantity>='Infinity'::numeric OR p_quantity='NaN'::numeric THEN RAISE EXCEPTION 'Shipment, leg, reference, SKU, finite positive quantity and idempotency key are required' USING errcode='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_shipment_legs l WHERE l.id=p_shipment_leg_id AND l.shipment_id=p_shipment_id AND l.partner_organization_id=p_organization_id AND l.status IN ('assigned','planned','in_transit','arrived')) THEN RAISE EXCEPTION 'Shipment leg is not assigned to this warehouse organisation or is not operational' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_warehouse_inventory i WHERE i.organization_id=p_organization_id AND i.facility_id=p_facility_id AND lower(i.sku)=lower(btrim(p_sku)) AND i.lot_code IS NOT DISTINCT FROM nullif(btrim(p_lot_code),'') AND i.quantity>=p_quantity AND i.quality_status='released') THEN RAISE EXCEPTION 'Insufficient released inventory for this shipment-linked pick' USING errcode='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('krim_wh_task:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 SELECT * INTO v_task FROM public.krim_warehouse_tasks WHERE organization_id=p_organization_id AND idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'picking_packing' OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id OR v_task.shipment_leg_id<>p_shipment_leg_id OR v_task.sku IS DISTINCT FROM nullif(btrim(p_sku),'') OR v_task.quantity IS DISTINCT FROM p_quantity THEN RAISE EXCEPTION 'Idempotency key was already used for a different pick task' USING errcode='23505'; END IF;
  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;
 INSERT INTO public.krim_warehouse_tasks(organization_id,facility_id,task_type,reference_code,sku,item_description,lot_code,quantity,unit_code,source_location,quality_status,severity,notes,idempotency_key,created_by,shipment_id,shipment_leg_id)
 VALUES(p_organization_id,p_facility_id,'picking_packing',btrim(p_reference_code),btrim(p_sku),nullif(btrim(p_item_description),''),nullif(btrim(p_lot_code),''),p_quantity,coalesce(nullif(btrim(p_unit_code),''),'unit'),nullif(btrim(p_source_location),''),'released','normal',left(coalesce(p_notes,''),4000),p_idempotency_key,v_user,p_shipment_id,p_shipment_leg_id) RETURNING * INTO v_task;
 INSERT INTO public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id) VALUES(v_task.id,p_organization_id,p_facility_id,'task.created','open',jsonb_build_object('task_type','picking_packing','shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id),v_user);
 RETURN jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
END; $function$;
REVOKE ALL ON FUNCTION public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_handover_task(
 p_organization_id bigint,p_facility_id uuid,p_shipment_id bigint,p_shipment_leg_id bigint,p_reference_code text,p_notes text,p_idempotency_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_user uuid:=auth.uid(); v_task public.krim_warehouse_tasks%rowtype;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode='28000'; END IF;
 IF NOT private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) THEN RAISE EXCEPTION 'Verified warehouse facility access and partner.manage permission required' USING errcode='42501'; END IF;
 IF p_shipment_id IS NULL OR p_shipment_leg_id IS NULL OR p_idempotency_key IS NULL OR nullif(btrim(p_reference_code),'') IS NULL OR length(btrim(p_reference_code))>120 THEN RAISE EXCEPTION 'Shipment, leg, outbound reference and idempotency key are required' USING errcode='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_shipment_legs l WHERE l.id=p_shipment_leg_id AND l.shipment_id=p_shipment_id AND l.partner_organization_id=p_organization_id AND l.status IN ('assigned','planned','in_transit','arrived')) THEN RAISE EXCEPTION 'Shipment leg is not assigned to this warehouse organisation or is not operational' USING errcode='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_warehouse_tasks t WHERE t.organization_id=p_organization_id AND t.facility_id=p_facility_id AND t.task_type='picking_packing' AND t.status='completed' AND t.reference_code=btrim(p_reference_code) AND t.shipment_id=p_shipment_id AND t.shipment_leg_id=p_shipment_leg_id) THEN RAISE EXCEPTION 'A completed pick/pack task linked to this exact shipment leg and outbound reference is required' USING errcode='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('krim_wh_task:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 SELECT * INTO v_task FROM public.krim_warehouse_tasks WHERE organization_id=p_organization_id AND idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_task.facility_id<>p_facility_id OR v_task.task_type<>'dispatch_handover' OR v_task.reference_code<>btrim(p_reference_code) OR v_task.shipment_id<>p_shipment_id OR v_task.shipment_leg_id<>p_shipment_leg_id THEN RAISE EXCEPTION 'Idempotency key was already used for a different handover task' USING errcode='23505'; END IF;
  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;
 INSERT INTO public.krim_warehouse_tasks(organization_id,facility_id,task_type,reference_code,quality_status,severity,notes,idempotency_key,created_by,shipment_id,shipment_leg_id)
 VALUES(p_organization_id,p_facility_id,'dispatch_handover',btrim(p_reference_code),'pending','normal',left(coalesce(p_notes,''),4000),p_idempotency_key,v_user,p_shipment_id,p_shipment_leg_id) RETURNING * INTO v_task;
 INSERT INTO public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id) VALUES(v_task.id,p_organization_id,p_facility_id,'task.created','open',jsonb_build_object('task_type','dispatch_handover','shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id),v_user);
 RETURN jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
END; $function$;
REVOKE ALL ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) TO authenticated;