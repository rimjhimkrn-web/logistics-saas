CREATE OR REPLACE FUNCTION krim_internal.cancel_notification_email_delivery(
  p_delivery_id bigint,p_worker_id text,p_reason text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,public
AS $function$
DECLARE v_delivery public.krim_notification_deliveries%rowtype; v_outbox public.krim_notification_outbox%rowtype;
BEGIN
  IF p_delivery_id IS NULL OR nullif(btrim(p_worker_id),'') IS NULL THEN RAISE EXCEPTION 'delivery_id_and_worker_required'; END IF;
  SELECT * INTO v_delivery FROM public.krim_notification_deliveries WHERE id=p_delivery_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT * INTO v_outbox FROM public.krim_notification_outbox WHERE id=v_delivery.outbox_id FOR UPDATE;
  IF NOT FOUND OR v_outbox.status<>'processing' OR COALESCE(v_outbox.metadata->>'worker_id','')<>p_worker_id THEN RETURN false; END IF;
  IF v_delivery.status NOT IN ('queued','sending') THEN RETURN false; END IF;
  UPDATE public.krim_notification_deliveries SET status='cancelled',
    last_error=left(COALESCE(nullif(btrim(p_reason),''),'recipient_not_eligible'),1000),updated_at=now()
  WHERE id=p_delivery_id;
  UPDATE public.krim_notification_outbox SET status='cancelled',
    last_error=left(COALESCE(nullif(btrim(p_reason),''),'recipient_not_eligible'),1000),
    next_attempt_at=NULL,metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id'
  WHERE id=v_outbox.id;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION krim_internal.cancel_notification_email_delivery(bigint,text,text)
FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION krim_internal.cancel_notification_email_delivery(bigint,text,text)
TO service_role;

CREATE OR REPLACE FUNCTION public.krim_cancel_email_notification_delivery(
  p_delivery_id bigint,p_worker_id text,p_reason text
) RETURNS boolean
LANGUAGE sql SECURITY DEFINER
SET search_path = pg_catalog,public,krim_internal
AS $function$ SELECT krim_internal.cancel_notification_email_delivery(p_delivery_id,p_worker_id,p_reason); $function$;
REVOKE ALL ON FUNCTION public.krim_cancel_email_notification_delivery(bigint,text,text)
FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_cancel_email_notification_delivery(bigint,text,text)
TO service_role;
COMMENT ON FUNCTION public.krim_cancel_email_notification_delivery(bigint,text,text)
IS 'Cancels a queued email delivery and its leased outbox item when recipient eligibility or provider support fails permanently.';
