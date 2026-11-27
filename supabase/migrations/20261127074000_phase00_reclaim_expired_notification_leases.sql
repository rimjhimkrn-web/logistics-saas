-- Recover worker crashes/timeouts by reclaiming expired processing leases.
CREATE OR REPLACE FUNCTION krim_internal.claim_email_notification_delivery(
  p_worker_id text,p_lease_seconds integer DEFAULT 300
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,public,krim_internal
AS $function$
DECLARE v_outbox_id bigint; v_result jsonb;
BEGIN
  IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN RAISE EXCEPTION 'worker_required'; END IF;
  IF p_lease_seconds NOT BETWEEN 30 AND 3600 THEN RAISE EXCEPTION 'invalid_lease_seconds'; END IF;
  WITH candidate AS (
    SELECT id FROM public.krim_notification_outbox
    WHERE channel='email'
      AND (
        (status='pending' AND scheduled_at<=now() AND (next_attempt_at IS NULL OR next_attempt_at<=now()))
        OR
        (status='processing' AND next_attempt_at<=now())
      )
    ORDER BY priority ASC,scheduled_at ASC,id ASC
    FOR UPDATE SKIP LOCKED LIMIT 1
  )
  UPDATE public.krim_notification_outbox o
  SET status='processing',attempt_count=o.attempt_count+1,
      next_attempt_at=now()+make_interval(secs=>p_lease_seconds),
      metadata=jsonb_set(COALESCE(o.metadata,'{}'::jsonb),'{worker_id}',to_jsonb(p_worker_id),true)
  FROM candidate c WHERE o.id=c.id
  RETURNING o.id INTO v_outbox_id;
  IF v_outbox_id IS NULL THEN RETURN jsonb_build_object('claimed',false,'reason','queue_empty'); END IF;
  v_result:=krim_internal.validate_notification_delivery(v_outbox_id,p_worker_id);
  RETURN jsonb_build_object('claimed',true,'outbox_id',v_outbox_id,'handoff',v_result);
END;
$function$;
REVOKE ALL ON FUNCTION krim_internal.claim_email_notification_delivery(text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.claim_email_notification_delivery(text,integer) TO service_role;
