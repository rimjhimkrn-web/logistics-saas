-- Require a real KRIM country catalogue reference for each new service capability.
DO $$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef('public.krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[])'::regprocedure) INTO v_def;
 IF position('p_coverage_country_id IS NOT NULL AND NOT EXISTS' in v_def)=0 THEN
   RAISE EXCEPTION 'Country validation guard not found';
 END IF;
 v_def:=replace(v_def,'p_coverage_country_id IS NOT NULL AND NOT EXISTS','p_coverage_country_id IS NULL OR NOT EXISTS');
 v_def:=replace(v_def,'message=''Coverage country is not recognized''','message=''Select a valid coverage country from the KRIM country catalogue''');
 EXECUTE v_def;
END $$;
