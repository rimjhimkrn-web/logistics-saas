-- Keep organisation verification separate from compliance clearance and commercial activation.
-- Approval records verified business identity only; a separate compliance decision is required.
DO $migration$
DECLARE
  v_def text;
  v_old text := $old$partner_lifecycle_status='active', partner_verification_status='verified',
        partner_compliance_status='compliant', partner_onboarding_status='completed',
        partner_onboarding_completed_at=now(), partner_verified_at=now(), partner_approved_at=now(),
        partner_activated_at=now(), partner_reviewed_at=now(),$old$;
  v_new text := $new$partner_lifecycle_status='approved', partner_verification_status='verified',
        partner_compliance_status='pending', partner_onboarding_status='submitted',
        partner_verified_at=now(), partner_approved_at=now(), partner_reviewed_at=now(),$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_review_partner_verification(bigint,text,text)'::regprocedure)
    INTO v_def;
  IF position(v_new in v_def)>0 THEN
    RETURN;
  END IF;
  IF position(v_old in v_def)=0 THEN
    RAISE EXCEPTION 'Expected partner verification approval state block not found; refusing unsafe replacement';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;
