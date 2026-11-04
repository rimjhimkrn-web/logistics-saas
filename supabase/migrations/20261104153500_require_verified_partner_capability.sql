DO $krim$
DECLARE d text;
BEGIN
  SELECT pg_get_functiondef('public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)'::regprocedure) INTO d;
  IF position('COALESCE(o.partner_account_mode, '''') <> ''development_test''' in d)=0 THEN RAISE EXCEPTION 'submit quote guard anchor missing'; END IF;
  d:=replace(d,'AND COALESCE(o.partner_account_mode, '''') <> ''development_test''',
    'AND o.partner_account_mode = ''registered_business''
    AND EXISTS (SELECT 1 FROM public.krim_partner_capabilities pc
      WHERE pc.organization_id=o.id AND pc.active IS TRUE AND pc.verification_status=''verified''
      AND (pc.effective_from IS NULL OR pc.effective_from<=now())
      AND (pc.effective_until IS NULL OR pc.effective_until>now()))');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_award_partner_quote(bigint)'::regprocedure) INTO d;
  IF position('AND o.partner_compliance_status IN' in d)=0 THEN RAISE EXCEPTION 'award quote guard anchor missing'; END IF;
  d:=replace(d,'AND o.organization_type IN (''partner'',''carrier'',''forwarder'')
      AND o.partner_verification_status',
    'AND o.organization_type IN (''partner'',''carrier'',''forwarder'')
      AND o.partner_account_mode = ''registered_business''
      AND EXISTS (SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id AND pc.active IS TRUE AND pc.verification_status=''verified''
        AND (pc.effective_from IS NULL OR pc.effective_from<=now())
        AND (pc.effective_until IS NULL OR pc.effective_until>now()))
      AND o.partner_verification_status');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure) INTO d;
  IF position('AND o.partner_compliance_status IN' in d)=0 THEN RAISE EXCEPTION 'assignment response guard anchor missing'; END IF;
  d:=replace(d,'AND o.status=''active''
        AND o.partner_verification_status',
    'AND o.status=''active''
        AND o.partner_account_mode=''registered_business''
        AND EXISTS (SELECT 1 FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id=o.id AND pc.active IS TRUE AND pc.verification_status=''verified''
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now()))
        AND o.partner_verification_status');
  EXECUTE d;
END $krim$;