-- Users may manage optional marketing preferences only. Essential service/security alerts remain mandatory.
CREATE OR REPLACE FUNCTION public.krim_set_notification_preference(
  p_organization_id bigint,
  p_notification_type text,
  p_channel text,
  p_enabled boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_id bigint;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;
  IF p_notification_type NOT IN ('marketing','product_updates') THEN
    RAISE EXCEPTION 'essential_notifications_cannot_be_disabled';
  END IF;
  IF p_channel NOT IN ('in_app','email','push','sms','webhook') THEN
    RAISE EXCEPTION 'unsupported_notification_channel';
  END IF;
  IF p_enabled IS NULL THEN RAISE EXCEPTION 'enabled_value_required'; END IF;
  IF p_organization_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    WHERE m.organization_id=p_organization_id AND m.user_id=v_user_id AND m.status='active'
  ) THEN RAISE EXCEPTION 'organization_access_denied'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    v_user_id::text||':'||COALESCE(p_organization_id::text,'global')||':'||p_notification_type||':'||p_channel,0
  ));

  SELECT id INTO v_id
  FROM public.krim_notification_preferences
  WHERE user_id=v_user_id
    AND organization_id IS NOT DISTINCT FROM p_organization_id
    AND notification_type=p_notification_type
    AND channel=p_channel
  ORDER BY id LIMIT 1 FOR UPDATE;

  IF v_id IS NULL THEN
    INSERT INTO public.krim_notification_preferences(user_id,organization_id,notification_type,channel,enabled)
    VALUES(v_user_id,p_organization_id,p_notification_type,p_channel,p_enabled);
  ELSE
    UPDATE public.krim_notification_preferences
    SET enabled=p_enabled,updated_at=clock_timestamp()
    WHERE id=v_id;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_set_notification_preference(bigint,text,text,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.krim_set_notification_preference(bigint,text,text,boolean) TO authenticated;

-- Bounded retry: after five claimed attempts, quarantine the outbox item in dead_letter.
CREATE OR REPLACE FUNCTION krim_internal.schedule_notification_retry(
  p_outbox_id bigint,
  p_worker_id text,
  p_error_code text,
  p_error_message text DEFAULT NULL,
  p_retry_seconds integer DEFAULT 300
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_row public.krim_notification_outbox%rowtype;
  v_retry_at timestamptz;
  v_new_status text;
BEGIN
  IF p_outbox_id IS NULL OR nullif(trim(p_worker_id),'') IS NULL THEN
    RAISE EXCEPTION 'outbox_id and worker_id required';
  END IF;
  IF p_retry_seconds < 5 OR p_retry_seconds > 86400 THEN
    RAISE EXCEPTION 'retry_seconds must be between 5 and 86400';
  END IF;

  SELECT * INTO v_row
  FROM public.krim_notification_outbox
  WHERE id=p_outbox_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_row.status <> 'processing'
     OR COALESCE(v_row.metadata->>'worker_id','') <> p_worker_id THEN
    RETURN false;
  END IF;

  IF v_row.attempt_count >= 5 THEN
    v_new_status := 'dead_letter';
    v_retry_at := NULL;
  ELSE
    v_new_status := 'pending';
    v_retry_at := clock_timestamp()+make_interval(secs=>p_retry_seconds);
  END IF;

  UPDATE public.krim_notification_outbox
  SET status=v_new_status,
      next_attempt_at=v_retry_at,
      last_error=left(COALESCE(p_error_code,'notification_failed')||
        CASE WHEN p_error_message IS NULL THEN '' ELSE ': '||p_error_message END,2000),
      metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id'
  WHERE id=p_outbox_id;

  INSERT INTO public.krim_notification_retry_events(
    outbox_id,previous_status,new_status,attempt_number,retry_at,error_code,error_message,worker_id
  ) VALUES (
    p_outbox_id,v_row.status,v_new_status,v_row.attempt_count,v_retry_at,
    p_error_code,p_error_message,p_worker_id
  );
  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.schedule_notification_retry(bigint,text,text,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.schedule_notification_retry(bigint,text,text,text,integer) TO service_role;

COMMENT ON FUNCTION public.krim_set_notification_preference(bigint,text,text,boolean)
IS 'Allows a signed-in member to change optional marketing preferences only; essential operational and security alerts cannot be disabled.';
COMMENT ON FUNCTION krim_internal.schedule_notification_retry(bigint,text,text,text,integer)
IS 'Worker-only notification retry with a five-attempt ceiling and dead-letter quarantine.';
