CREATE OR REPLACE FUNCTION public.krim_partner_submit_service_capability_v2(
 p_organization_id bigint,p_transport_mode_id bigint,p_service_type text,p_coverage_country_id bigint,
 p_coverage_region text,p_max_weight_kg numeric,p_refrigerated boolean,p_hazardous_goods_capable boolean,
 p_evidence_paths text[],p_submission_details jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_result jsonb;v_capability_id bigint;v_details jsonb:=coalesce(p_submission_details,'{}'::jsonb);
BEGIN
 IF jsonb_typeof(v_details)<>'object' OR octet_length(v_details::text)>5000
 THEN RAISE EXCEPTION USING errcode='22023',message='Capability details must be a JSON object of at most 5 KB';END IF;
 IF char_length(coalesce(v_details->>'equipment_details',''))>300
 OR char_length(coalesce(v_details->>'operational_constraints',''))>1500
 THEN RAISE EXCEPTION USING errcode='22023',message='Capability details exceed permitted lengths';END IF;
 v_result:=public.krim_partner_submit_service_capability(p_organization_id,p_transport_mode_id,p_service_type,
 p_coverage_country_id,p_coverage_region,p_max_weight_kg,p_refrigerated,p_hazardous_goods_capable,p_evidence_paths);
 v_capability_id:=(v_result->>'capability_id')::bigint;
 UPDATE public.krim_partner_capabilities SET metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
 'submission_details',jsonb_build_object('equipment_details',nullif(btrim(v_details->>'equipment_details'),''),
 'operational_constraints',nullif(btrim(v_details->>'operational_constraints'),''))) WHERE id=v_capability_id;
 RETURN v_result||jsonb_build_object('details_saved',true);
END;$function$;
REVOKE ALL ON FUNCTION public.krim_partner_submit_service_capability_v2(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[],jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_partner_submit_service_capability_v2(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[],jsonb) TO authenticated;