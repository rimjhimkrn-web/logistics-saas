-- Guarded essential-email producer. No provider means no queue row and no external send.
CREATE OR REPLACE FUNCTION krim_internal.enqueue_essential_email_notification(
  p_event_id uuid,
  p_recipient_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, krim_internal
AS $function$
DECLARE
  v_event public.krim_events%rowtype;
  v_provider public.krim_communication_providers%rowtype;
  v_subject text;
  v_message text;
  v_key text;
  v_outbox_id bigint;
BEGIN
  IF p_event_id IS NULL OR p_recipient_user_id IS NULL THEN
    RETURN jsonb_build_object('queued',false,'reason','event_and_recipient_required');
  END IF;

  SELECT * INTO v_event FROM public.krim_events e
  WHERE e.event_id=p_event_id
  FOR SHARE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('queued',false,'reason','event_not_found');
  END IF;

  -- Only audited, essential operational events are eligible for this producer.
  IF v_event.event_type NOT IN (
    'shipment.created','shipment.status_changed',
    'partner.assignment_offered','partner.assignment_status_changed'
  ) THEN
    RETURN jsonb_build_object('queued',false,'reason','event_type_not_allowlisted');
  END IF;

  IF v_event.organization_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.organization_id=v_event.organization_id
      AND m.user_id=p_recipient_user_id
      AND m.status='active'
      AND o.status='active'
  ) THEN
    RETURN jsonb_build_object('queued',false,'reason','recipient_not_active_org_member');
  END IF;

  IF NOT krim_internal.krim_notification_email_recipient_eligible(
    p_recipient_user_id,v_event.organization_id,'essential'
  ) THEN
    RETURN jsonb_build_object('queued',false,'reason','recipient_email_not_eligible');
  END IF;

  CASE v_event.event_type
    WHEN 'shipment.created' THEN
      v_subject := 'KRIM shipment booking received';
      v_message := 'A shipment booking has been created. Sign in to your KRIM workspace to review its details.';
    WHEN 'shipment.status_changed' THEN
      v_subject := 'KRIM shipment status update';
      v_message := 'A shipment status has changed. Sign in to your KRIM workspace to review the latest status.';
    WHEN 'partner.assignment_offered' THEN
      v_subject := 'KRIM shipment assignment available';
      v_message := 'A shipment assignment is awaiting your review. Sign in to your KRIM partner workspace.';
    WHEN 'partner.assignment_status_changed' THEN
      v_subject := 'KRIM partner assignment update';
      v_message := 'A partner assignment status has changed. Sign in to your KRIM partner workspace.';
  END CASE;

  SELECT * INTO v_provider
  FROM public.krim_communication_providers cp
  WHERE cp.channel='email' AND cp.status='active'
    AND cp.credential_reference IS NOT NULL
    AND btrim(cp.credential_reference)<>''
  ORDER BY cp.priority,cp.id
  LIMIT 1;

  IF v_provider.id IS NULL THEN
    RETURN jsonb_build_object('queued',false,'reason','email_provider_not_configured');
  END IF;

  v_key := 'event:'||p_event_id::text||':user:'||p_recipient_user_id::text||':email:essential';

  INSERT INTO public.krim_notification_outbox(
    event_id,organization_id,recipient_type,recipient_reference,
    notification_type,channel,provider,subject,message,payload,
    status,scheduled_at,idempotency_key,metadata
  ) VALUES (
    v_event.event_id,v_event.organization_id,'user',p_recipient_user_id::text,
    v_event.event_type,'email',v_provider.provider_name,v_subject,v_message,
    jsonb_build_object('event_type',v_event.event_type,'entity_type',v_event.entity_type,'entity_id',v_event.entity_id),
    'pending',now(),v_key,
    jsonb_build_object('notification_class','essential','recipient_user_id',p_recipient_user_id,'eligibility_checked_at',now())
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_outbox_id;

  IF v_outbox_id IS NULL THEN
    SELECT id INTO v_outbox_id FROM public.krim_notification_outbox WHERE idempotency_key=v_key;
    RETURN jsonb_build_object('queued',false,'duplicate',true,'outbox_id',v_outbox_id);
  END IF;

  RETURN jsonb_build_object('queued',true,'duplicate',false,'outbox_id',v_outbox_id);
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.enqueue_essential_email_notification(uuid,uuid)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.enqueue_essential_email_notification(uuid,uuid)
TO service_role;

COMMENT ON FUNCTION krim_internal.enqueue_essential_email_notification(uuid,uuid)
IS 'Queues only allowlisted essential operational email for an active confirmed recipient and configured provider. Marketing is excluded. Idempotent per event/user/channel. Does not send email.';
