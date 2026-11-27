-- Close NULL category bypass and connect allowlisted org events to the guarded email producer.
CREATE OR REPLACE FUNCTION krim_internal.krim_notification_email_recipient_eligible(
  p_user_id uuid,p_organization_id bigint,p_notification_class text
) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
DECLARE v_email text; v_confirmed_at timestamptz; v_deleted_at timestamptz; v_consent boolean; v_preference boolean;
BEGIN
  IF p_user_id IS NULL OR p_notification_class IS NULL
     OR p_notification_class NOT IN ('essential','marketing') THEN RETURN false; END IF;
  SELECT u.email,u.email_confirmed_at,u.deleted_at INTO v_email,v_confirmed_at,v_deleted_at
  FROM auth.users u WHERE u.id=p_user_id;
  IF NOT FOUND OR v_deleted_at IS NOT NULL OR nullif(btrim(v_email),'') IS NULL OR v_confirmed_at IS NULL THEN RETURN false; END IF;
  IF p_organization_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.organization_id=p_organization_id AND m.user_id=p_user_id AND m.status='active' AND o.status='active'
  ) THEN RETURN false; END IF;
  IF p_notification_class='essential' THEN RETURN true; END IF;
  SELECT c.granted INTO v_consent FROM public.krim_user_consent_events c
  WHERE c.user_id=p_user_id AND c.consent_type='marketing_email'
  ORDER BY c.created_at DESC,c.id DESC LIMIT 1;
  IF COALESCE(v_consent,false) IS NOT TRUE THEN RETURN false; END IF;
  SELECT np.enabled INTO v_preference FROM public.krim_notification_preferences np
  WHERE np.user_id=p_user_id AND np.organization_id IS NOT DISTINCT FROM p_organization_id
    AND np.notification_type='marketing' AND np.channel='email'
  ORDER BY np.updated_at DESC NULLS LAST,np.id DESC LIMIT 1;
  RETURN COALESCE(v_preference,false);
END;
$function$;

CREATE OR REPLACE FUNCTION krim_internal.krim_enqueue_event_essential_emails()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, krim_internal
AS $function$
DECLARE v_member record;
BEGIN
  IF NEW.event_type NOT IN (
    'shipment.created','shipment.status_changed',
    'partner.assignment_offered','partner.assignment_status_changed'
  ) OR NEW.organization_id IS NULL THEN
    RETURN NEW;
  END IF;

  FOR v_member IN
    SELECT DISTINCT m.user_id
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.organization_id=NEW.organization_id
      AND m.status='active' AND o.status='active'
  LOOP
    PERFORM krim_internal.enqueue_essential_email_notification(NEW.event_id,v_member.user_id);
  END LOOP;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.krim_enqueue_event_essential_emails()
FROM PUBLIC,anon,authenticated,service_role;

DROP TRIGGER IF EXISTS trg_krim_enqueue_event_essential_emails ON public.krim_events;
CREATE TRIGGER trg_krim_enqueue_event_essential_emails
AFTER INSERT ON public.krim_events
FOR EACH ROW EXECUTE FUNCTION krim_internal.krim_enqueue_event_essential_emails();

COMMENT ON FUNCTION krim_internal.krim_enqueue_event_essential_emails()
IS 'Event trigger that attempts allowlisted essential email enqueue for active members of the event organization. The guarded producer rejects unconfirmed recipients and missing providers; this trigger never sends email.';
