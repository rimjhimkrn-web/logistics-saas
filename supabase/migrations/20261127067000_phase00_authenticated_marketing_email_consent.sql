-- Append-only authenticated marketing email consent capture.
-- Consent withdrawal is another event (granted=false); no user can rewrite history.
CREATE OR REPLACE FUNCTION public.krim_set_email_marketing_consent(
  p_granted boolean,
  p_policy_version text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_consent_event_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF p_granted IS NULL THEN
    RAISE EXCEPTION 'consent_decision_required';
  END IF;
  IF nullif(btrim(p_policy_version),'') IS NULL THEN
    RAISE EXCEPTION 'policy_version_required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id=v_user_id AND u.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active_user_required';
  END IF;

  INSERT INTO public.krim_user_consent_events(user_id,consent_type,granted,policy_version)
  VALUES(v_user_id,'marketing_email',p_granted,btrim(p_policy_version))
  RETURNING id INTO v_consent_event_id;

  RETURN v_consent_event_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_set_email_marketing_consent(boolean,text)
FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.krim_set_email_marketing_consent(boolean,text)
TO authenticated;

COMMENT ON FUNCTION public.krim_set_email_marketing_consent(boolean,text)
IS 'Append-only marketing email consent capture for the authenticated user. Withdrawal is recorded as granted=false; no essential service notification preference is changed.';
