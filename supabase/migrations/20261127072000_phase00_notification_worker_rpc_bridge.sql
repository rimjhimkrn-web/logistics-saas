-- PostgREST-facing service-role bridge for the general email worker.
CREATE OR REPLACE FUNCTION public.krim_claim_email_notification_delivery(
  p_worker_id text,p_lease_seconds integer DEFAULT 300
) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER
SET search_path = pg_catalog, public, krim_internal
AS $function$
  SELECT krim_internal.claim_email_notification_delivery(p_worker_id,p_lease_seconds);
$function$;

CREATE OR REPLACE FUNCTION public.krim_check_notification_email_eligibility(
  p_user_id uuid,p_organization_id bigint,p_notification_class text
) RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog, public, krim_internal
AS $function$
  SELECT krim_internal.krim_notification_email_recipient_eligible(p_user_id,p_organization_id,p_notification_class);
$function$;

CREATE OR REPLACE FUNCTION public.krim_complete_email_notification_delivery(
  p_delivery_id bigint,p_worker_id text,p_success boolean,
  p_provider_message_id text DEFAULT NULL,p_error_code text DEFAULT NULL,p_error_message text DEFAULT NULL
) RETURNS boolean
LANGUAGE sql SECURITY DEFINER
SET search_path = pg_catalog, public, krim_internal
AS $function$
  SELECT krim_internal.complete_notification_delivery(
    p_delivery_id,p_worker_id,p_success,p_provider_message_id,p_error_code,p_error_message
  );
$function$;

REVOKE ALL ON FUNCTION public.krim_claim_email_notification_delivery(text,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.krim_check_notification_email_eligibility(uuid,bigint,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.krim_complete_email_notification_delivery(bigint,text,boolean,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_claim_email_notification_delivery(text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.krim_check_notification_email_eligibility(uuid,bigint,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.krim_complete_email_notification_delivery(bigint,text,boolean,text,text,text) TO service_role;

COMMENT ON FUNCTION public.krim_claim_email_notification_delivery(text,integer)
IS 'Service-role PostgREST bridge to the atomic email outbox claim and delivery handoff.';
COMMENT ON FUNCTION public.krim_check_notification_email_eligibility(uuid,bigint,text)
IS 'Service-role-only final recipient eligibility check for the general email worker.';
COMMENT ON FUNCTION public.krim_complete_email_notification_delivery(bigint,text,boolean,text,text,text)
IS 'Service-role-only completion bridge for general notification delivery attempts.';
