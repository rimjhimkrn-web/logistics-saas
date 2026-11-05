DO $$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure) INTO v_def;
 IF position('jsonb_array_length(coalesce(v_evidence,''[]''::jsonb)) not between 1 and 5' in v_def)=0 THEN
   RAISE EXCEPTION 'Expected evidence array guard not found';
 END IF;
 v_def:=replace(v_def,
   'jsonb_array_length(coalesce(v_evidence,''[]''::jsonb)) not between 1 and 5',
   '(case when jsonb_typeof(v_evidence)=''array'' then jsonb_array_length(v_evidence) else 0 end) not between 1 and 5');
 EXECUTE v_def;
END $$;