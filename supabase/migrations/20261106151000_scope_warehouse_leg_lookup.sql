DROP FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint);
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
 RETURN QUERY SELECT l.shipment_id,l.id,s.shipment_number,l.leg_sequence,l.status
 FROM public.krim_shipment_legs l JOIN public.krim_shipments s ON s.id=l.shipment_id
 WHERE l.partner_organization_id=p_organization_id
 AND l.status IN ('assigned','planned','in_transit','arrived')
 ORDER BY s.created_at DESC,l.leg_sequence;
END; $$;
REVOKE ALL ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) TO authenticated;
