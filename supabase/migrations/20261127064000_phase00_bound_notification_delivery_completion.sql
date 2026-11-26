-- Bound the second delivery completion path to a worker lease and five attempts.
CREATE OR REPLACE FUNCTION krim_internal.complete_notification_delivery(
 p_delivery_id bigint,p_worker_id text,p_success boolean,p_provider_message_id text DEFAULT NULL,
 p_error_code text DEFAULT NULL,p_error_message text DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public
AS $function$
DECLARE v_delivery public.krim_notification_deliveries%rowtype; v_outbox public.krim_notification_outbox%rowtype; v_next timestamptz; v_status text;
BEGIN
 IF p_delivery_id IS NULL OR nullif(trim(p_worker_id),'') IS NULL THEN RAISE EXCEPTION 'delivery_id and worker_id required'; END IF;
 SELECT * INTO v_delivery FROM public.krim_notification_deliveries WHERE id=p_delivery_id FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 SELECT * INTO v_outbox FROM public.krim_notification_outbox WHERE id=v_delivery.outbox_id FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF COALESCE(v_outbox.metadata->>'worker_id','')<>p_worker_id OR v_outbox.status<>'processing' THEN RETURN false; END IF;
 IF v_delivery.status IN ('sent','delivered','failed') THEN RETURN true; END IF;
 IF p_success THEN
  UPDATE public.krim_notification_deliveries SET status='sent',sent_at=COALESCE(sent_at,now()),provider_message_id=COALESCE(p_provider_message_id,provider_message_id),last_error=NULL,updated_at=now() WHERE id=p_delivery_id;
  UPDATE public.krim_notification_outbox SET status='sent',sent_at=COALESCE(sent_at,now()),delivered_at=COALESCE(delivered_at,now()),provider_message_id=COALESCE(p_provider_message_id,provider_message_id),last_error=NULL,metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id',next_attempt_at=NULL WHERE id=v_outbox.id;
 ELSE
  IF v_outbox.attempt_count>=5 THEN v_status:='dead_letter'; v_next:=NULL;
  ELSE v_status:='pending'; v_next:=now()+make_interval(secs=>LEAST(3600,300*power(2,GREATEST(v_outbox.attempt_count-1,0))::integer)); END IF;
  UPDATE public.krim_notification_deliveries SET status='failed',failed_at=COALESCE(failed_at,now()),last_error=left(COALESCE(p_error_code,'delivery_failed')||CASE WHEN p_error_message IS NULL THEN '' ELSE ': '||p_error_message END,2000),updated_at=now() WHERE id=p_delivery_id;
  UPDATE public.krim_notification_outbox SET status=v_status,next_attempt_at=v_next,last_error=left(COALESCE(p_error_code,'delivery_failed')||CASE WHEN p_error_message IS NULL THEN '' ELSE ': '||p_error_message END,2000),metadata=COALESCE(metadata,'{}'::jsonb)-'worker_id' WHERE id=v_outbox.id;
  INSERT INTO public.krim_notification_retry_events(outbox_id,previous_status,new_status,attempt_number,retry_at,error_code,error_message,worker_id)
  VALUES(v_outbox.id,v_outbox.status,v_status,v_outbox.attempt_count,v_next,p_error_code,p_error_message,p_worker_id);
 END IF;
 RETURN true;
END;$function$;
REVOKE ALL ON FUNCTION krim_internal.complete_notification_delivery(bigint,text,boolean,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.complete_notification_delivery(bigint,text,boolean,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION krim_internal.mark_notification_delivery_result(bigint,boolean,text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION krim_internal.complete_notification_delivery(bigint,text,boolean,text,text,text) IS 'Completes a leased notification delivery; retries are bounded to five attempts and then dead-lettered.';
COMMENT ON FUNCTION krim_internal.mark_notification_delivery_result(bigint,boolean,text,text) IS 'Deprecated unsafe legacy result writer; execution revoked in favor of worker-lease-checked completion.';
