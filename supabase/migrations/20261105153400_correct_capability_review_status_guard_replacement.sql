-- Accept the same normalized organization status values as partner capacity
-- and capability submission gates. No relaxation of MFA/admin permission gates.
DO $$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure) INTO v_def;
 IF position('coalesce(v_org_lifecycle,'''')<>''active''' in v_def)=0 THEN RAISE EXCEPTION 'Lifecycle guard not found'; END IF;
 IF position('coalesce(v_org_verification,'''')<>''verified''' in v_def)=0 THEN RAISE EXCEPTION 'Verification guard not found'; END IF;
 IF position('coalesce(v_org_compliance,'''')<>''compliant''' in v_def)=0 THEN RAISE EXCEPTION 'Compliance guard not found'; END IF;
 v_def:=replace(v_def,'coalesce(v_org_lifecycle,'''')<>''active''','coalesce(v_org_lifecycle,'''') not in (''active'',''verified'')');
 v_def:=replace(v_def,'coalesce(v_org_verification,'''')<>''verified''','coalesce(v_org_verification,'''') not in (''verified'',''approved'')');
 v_def:=replace(v_def,'coalesce(v_org_compliance,'''')<>''compliant''','coalesce(v_org_compliance,'''') not in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')');
 EXECUTE v_def;
END $$;
