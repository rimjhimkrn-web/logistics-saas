-- Use a bracketed literal dot in the category-scoped evidence filename matcher.
DO $$
DECLARE d text; old_pattern text:=repeat(chr(92),2)||'.';
BEGIN
 SELECT pg_get_functiondef('public.krim_partner_submit_compliance_evidence(bigint,jsonb,text)'::regprocedure) INTO d;
 IF position('[.]' in d)=0 THEN
  d:=replace(d,old_pattern,'[.]');
  IF position('[.]' in d)=0 THEN RAISE EXCEPTION 'Could not normalize evidence file extension matcher'; END IF;
  EXECUTE d;
 END IF;
END $$;