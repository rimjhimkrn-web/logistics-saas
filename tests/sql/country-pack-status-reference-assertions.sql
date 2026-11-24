DO $$
DECLARE
  v_definition text;
  v_result jsonb;
  v_oid oid := 'public.krim_admin_review_partner_service_area(bigint,text,text)'::regprocedure;
BEGIN
  SELECT pg_get_functiondef(v_oid) INTO v_definition;
  IF position('cp.pack_status=''approved''' IN v_definition)=0 THEN
    RAISE EXCEPTION 'Expected pack_status reference after repair';
  END IF;
  IF position('cp.status=''approved''' IN v_definition)>0 THEN
    RAISE EXCEPTION 'Invalid status reference remains after repair';
  END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid=v_oid) THEN
    RAISE EXCEPTION 'SECURITY DEFINER property changed unexpectedly';
  END IF;
  IF NOT has_function_privilege('authenticated',v_oid,'EXECUTE') THEN
    RAISE EXCEPTION 'Existing authenticated EXECUTE grant was not preserved';
  END IF;
  IF has_function_privilege('anon',v_oid,'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous EXECUTE privilege unexpectedly present';
  END IF;
  v_result := public.krim_admin_review_partner_service_area(1,'approved','test-only');
  IF v_result->>'approved' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Repaired function did not execute against approved pack: %',v_result;
  END IF;
END $$;
