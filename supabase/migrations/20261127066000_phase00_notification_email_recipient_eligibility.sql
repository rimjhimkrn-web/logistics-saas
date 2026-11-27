-- Narrow email eligibility gate. This does not enqueue or send email.
-- Essential service email requires a live user, confirmed email and (when scoped) active org membership.
-- Marketing email additionally requires the latest explicit marketing_email consent and an enabled preference.
CREATE OR REPLACE FUNCTION krim_internal.krim_notification_email_recipient_eligible(
  p_user_id uuid,
  p_organization_id bigint,
  p_notification_class text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
DECLARE
  v_email text;
  v_confirmed_at timestamptz;
  v_deleted_at timestamptz;
  v_consent boolean;
  v_preference boolean;
BEGIN
  IF p_user_id IS NULL OR p_notification_class NOT IN ('essential','marketing') THEN
    RETURN false;
  END IF;

  SELECT u.email,u.email_confirmed_at,u.deleted_at
    INTO v_email,v_confirmed_at,v_deleted_at
  FROM auth.users u
  WHERE u.id=p_user_id;

  IF NOT FOUND OR v_deleted_at IS NOT NULL
     OR nullif(btrim(v_email),'') IS NULL
     OR v_confirmed_at IS NULL THEN
    RETURN false;
  END IF;

  IF p_organization_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.organization_id=p_organization_id
      AND m.user_id=p_user_id
      AND m.status='active'
      AND o.status='active'
  ) THEN
    RETURN false;
  END IF;

  IF p_notification_class='essential' THEN
    RETURN true;
  END IF;

  SELECT c.granted INTO v_consent
  FROM public.krim_user_consent_events c
  WHERE c.user_id=p_user_id
    AND c.consent_type='marketing_email'
  ORDER BY c.created_at DESC,c.id DESC
  LIMIT 1;

  IF COALESCE(v_consent,false) IS NOT TRUE THEN
    RETURN false;
  END IF;

  SELECT np.enabled INTO v_preference
  FROM public.krim_notification_preferences np
  WHERE np.user_id=p_user_id
    AND np.organization_id IS NOT DISTINCT FROM p_organization_id
    AND np.notification_type='marketing'
    AND np.channel='email'
  ORDER BY np.updated_at DESC NULLS LAST,np.id DESC
  LIMIT 1;

  -- Require an explicit enabled preference as well as recorded consent.
  RETURN COALESCE(v_preference,false);
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.krim_notification_email_recipient_eligible(uuid,bigint,text)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.krim_notification_email_recipient_eligible(uuid,bigint,text)
TO service_role;

COMMENT ON FUNCTION krim_internal.krim_notification_email_recipient_eligible(uuid,bigint,text)
IS 'Fail-closed email eligibility check only; does not enqueue or send. Essential email requires confirmed active recipient; marketing requires latest affirmative marketing_email consent and explicit enabled preference.';
