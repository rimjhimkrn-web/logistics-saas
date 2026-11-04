-- Prevent legacy invitation-response RPC from bypassing the registered-business,
-- organisation verification/compliance, and capability approval gates.
DO $$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef('public.krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamp with time zone,text)'::regprocedure)
  INTO v_def;
  IF position('Only verified registered-business partners with an active verified capability may accept commercial invitations' in v_def)=0 THEN
    v_def := replace(
      v_def,
      'if p_amount is null or p_amount<0 then raise exception ''Partner quote amount is required''; end if;',
      $guard$
IF NOT EXISTS (
  SELECT 1
  FROM public.krim_organizations o
  WHERE o.id = v_org
    AND o.organization_type IN ('partner','carrier','forwarder')
    AND o.status = 'active'
    AND o.partner_account_mode = 'registered_business'
    AND o.partner_verification_status IN ('verified','approved')
    AND o.partner_lifecycle_status IN ('active','verified')
    AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    AND EXISTS (
      SELECT 1
      FROM public.krim_partner_capabilities pc
      WHERE pc.organization_id = o.id
        AND pc.active IS TRUE
        AND pc.verification_status = 'verified'
        AND (pc.effective_from IS NULL OR pc.effective_from <= now())
        AND (pc.effective_until IS NULL OR pc.effective_until > now())
    )
) THEN
  RAISE EXCEPTION USING errcode='42501',
    message='Only verified registered-business partners with an active verified capability may accept commercial invitations';
END IF;
if p_amount is null or p_amount<0 then raise exception 'Partner quote amount is required'; end if;
$guard$
    );
    IF position('Only verified registered-business partners with an active verified capability may accept commercial invitations' in v_def)=0 THEN
      RAISE EXCEPTION 'Expected function insertion point was not found; no change applied';
    END IF;
    EXECUTE v_def;
  END IF;
END $$;
