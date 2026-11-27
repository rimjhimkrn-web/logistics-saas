-- Recheck email recipient eligibility immediately before delivery creation.
-- Legacy/unclassified email outbox rows fail closed; the specialized Resend queue is separate.
CREATE OR REPLACE FUNCTION krim_internal.validate_notification_delivery(
  p_outbox_id bigint,p_worker_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, auth, krim_internal
AS $function$
DECLARE
  v_outbox public.krim_notification_outbox%rowtype;
  v_provider public.krim_communication_providers%rowtype;
  v_delivery_id bigint;
  v_recipient_user_id uuid;
  v_notification_class text;
BEGIN
  IF p_outbox_id IS NULL OR nullif(btrim(p_worker_id),'') IS NULL THEN
    RAISE EXCEPTION 'outbox_id and worker_id required';
  END IF;
  SELECT * INTO v_outbox FROM public.krim_notification_outbox WHERE id=p_outbox_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'outbox_not_found'; END IF;
  IF v_outbox.status <> 'processing' OR COALESCE(v_outbox.metadata->>'worker_id','') <> p_worker_id THEN
    RAISE EXCEPTION 'outbox_worker_mismatch';
  END IF;

  IF v_outbox.channel='email' THEN
    v_notification_class:=v_outbox.metadata->>'notification_class';
    IF v_outbox.recipient_type<>'user'
       OR v_notification_class NOT IN ('essential','marketing')
       OR COALESCE(v_outbox.metadata->>'recipient_user_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      UPDATE public.krim_notification_outbox SET status='cancelled',
        last_error='email_recipient_metadata_invalid_at_dispatch',next_attempt_at=NULL,
        metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id' WHERE id=v_outbox.id;
      RETURN jsonb_build_object('outbox_id',v_outbox.id,'status','cancelled','reason','email_recipient_metadata_invalid_at_dispatch');
    END IF;
    v_recipient_user_id:=(v_outbox.metadata->>'recipient_user_id')::uuid;
    IF NOT krim_internal.krim_notification_email_recipient_eligible(
      v_recipient_user_id,v_outbox.organization_id,v_notification_class
    ) THEN
      UPDATE public.krim_notification_outbox SET status='cancelled',
        last_error='recipient_email_not_eligible_at_dispatch',next_attempt_at=NULL,
        metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id' WHERE id=v_outbox.id;
      RETURN jsonb_build_object('outbox_id',v_outbox.id,'status','cancelled','reason','recipient_email_not_eligible_at_dispatch');
    END IF;
  END IF;

  SELECT * INTO v_provider FROM public.krim_communication_providers
  WHERE provider_name=v_outbox.provider AND channel=v_outbox.channel AND status='active'
  ORDER BY priority ASC,id ASC LIMIT 1;
  IF v_provider.id IS NULL THEN
    UPDATE public.krim_notification_outbox SET status='failed',last_error='active_provider_not_configured',
      next_attempt_at=NULL,metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id' WHERE id=v_outbox.id;
    RETURN jsonb_build_object('outbox_id',v_outbox.id,'status','failed','reason','active_provider_not_configured');
  END IF;
  IF nullif(btrim(v_provider.credential_reference),'') IS NULL THEN
    UPDATE public.krim_notification_outbox SET status='failed',last_error='provider_credential_reference_missing',
      next_attempt_at=NULL,metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id' WHERE id=v_outbox.id;
    RETURN jsonb_build_object('outbox_id',v_outbox.id,'status','failed','reason','provider_credential_reference_missing');
  END IF;
  SELECT id INTO v_delivery_id FROM public.krim_notification_deliveries
  WHERE outbox_id=v_outbox.id AND status IN ('queued','sending')
  ORDER BY id DESC LIMIT 1 FOR UPDATE;
  IF v_delivery_id IS NULL THEN
    INSERT INTO public.krim_notification_deliveries(outbox_id,channel,provider,status,attempt_count,next_attempt_at)
    VALUES(v_outbox.id,v_outbox.channel,v_provider.provider_name,'queued',v_outbox.attempt_count,clock_timestamp())
    RETURNING id INTO v_delivery_id;
  END IF;
  RETURN jsonb_build_object('outbox_id',v_outbox.id,'delivery_id',v_delivery_id,'status','queued',
    'provider',v_provider.provider_name,'credential_reference_present',true);
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.validate_notification_delivery(bigint,text)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.validate_notification_delivery(bigint,text)
TO service_role;

COMMENT ON FUNCTION krim_internal.validate_notification_delivery(bigint,text)
IS 'Validates worker lease and provider, rechecks email recipient confirmation/org membership and current marketing consent/preferences immediately before delivery row creation; fails closed for unclassified email rows.';
