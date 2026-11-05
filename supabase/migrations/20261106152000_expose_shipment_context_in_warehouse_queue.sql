CREATE OR REPLACE FUNCTION public.krim_warehouse_list_tasks(p_task_type text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_user uuid:=auth.uid(); v_items jsonb;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode='28000'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]'::jsonb) INTO v_items
 FROM (
  SELECT t.id,t.organization_id,o.legal_name organization_name,t.facility_id,f.facility_code,f.facility_name,
   t.task_type,t.reference_code,t.sku,t.item_description,t.lot_code,t.quantity,t.unit_code,
   t.source_location,t.destination_location,t.quality_status,t.severity,t.status,t.notes,
   t.shipment_id,t.shipment_leg_id,s.shipment_number,l.leg_sequence,
   t.created_at,t.updated_at,t.completed_at
  FROM public.krim_warehouse_tasks t
  JOIN public.krim_organizations o ON o.id=t.organization_id
  JOIN public.krim_warehouse_facilities f ON f.id=t.facility_id
  LEFT JOIN public.krim_shipments s ON s.id=t.shipment_id
  LEFT JOIN public.krim_shipment_legs l ON l.id=t.shipment_leg_id AND l.shipment_id=t.shipment_id
  WHERE (p_task_type IS NULL OR t.task_type=p_task_type)
   AND private.krim_warehouse_is_operator(v_user,t.organization_id,t.facility_id)
  ORDER BY t.created_at DESC LIMIT 250
 ) x;
 RETURN jsonb_build_object('items',v_items);
END; $$;
