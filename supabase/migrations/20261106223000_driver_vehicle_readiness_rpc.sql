CREATE OR REPLACE FUNCTION public.krim_driver_my_vehicle()
RETURNS TABLE(vehicle_id uuid,registration_country_code text,registration_number text,vehicle_category text,vehicle_type text,payload_capacity numeric,payload_unit text,verification_status text,operational_status text,binding_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND lower(m.role)='driver' AND lower(m.status)='active') THEN RAISE EXCEPTION USING errcode='42501',message='Active driver membership required';END IF;
 RETURN QUERY SELECT v.id,v.registration_country_code,v.registration_number,v.vehicle_category,v.vehicle_type,v.payload_capacity,v.payload_unit,v.verification_status,v.operational_status,b.status
 FROM public.krim_vehicle_driver_bindings b JOIN public.krim_vehicles v ON v.id=b.vehicle_id AND v.organization_id=b.organization_id
 WHERE b.driver_user_id=v_user AND b.status='active' ORDER BY b.created_at DESC LIMIT 1;
END;$$;
REVOKE ALL ON FUNCTION public.krim_driver_my_vehicle() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_my_vehicle() TO authenticated;