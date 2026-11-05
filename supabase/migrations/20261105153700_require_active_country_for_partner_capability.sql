-- Only active countries in the KRIM reference catalogue may be selected for
-- new partner capability coverage.
DO $$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef('public.krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[])'::regprocedure) INTO v_def;
 IF position('FROM public.krim_countries WHERE id=p_coverage_country_id' in v_def)=0 THEN
  RAISE EXCEPTION 'Country lookup guard not found';
 END IF;
 v_def:=replace(v_def,'FROM public.krim_countries WHERE id=p_coverage_country_id','FROM public.krim_countries WHERE id=p_coverage_country_id AND is_active=true');
 EXECUTE v_def;
END $$;
