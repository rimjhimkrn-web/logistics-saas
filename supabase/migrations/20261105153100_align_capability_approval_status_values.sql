DO $$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure) INTO v_def;
 IF position('coalesce(v_org_lifecycle,'''')<>''active''' in v_def)=0
 OR position('coalesce(v_org_compliance,'''')<>''compliant''' in v_def)=0
 THEN RAISE EXCEPTION 'Expected partner capability approval guard not found; aborting safely';END IF;
 v_def:=replace(v_def,
 'coalesce(v_org_lifecycle,'''')<>''active'' or coalesce(v_org_verification,'''')<>''verified'' or coalesce(v_org_compliance,'''')<>''compliant''',
 'coalesce(v_org_lifecycle,'''') not in (''active'',''verified'') or coalesce(v_org_verification,'''') not in (''verified'',''approved'') or coalesce(v_org_compliance,'''') not in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')');
 EXECUTE v_def;
END $$;