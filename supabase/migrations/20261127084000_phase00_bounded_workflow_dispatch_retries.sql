ALTER TABLE public.krim_event_workflow_dispatches
 ADD COLUMN IF NOT EXISTS processing_attempts integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz,
 ADD COLUMN IF NOT EXISTS last_attempted_at timestamptz;
ALTER TABLE public.krim_event_workflow_dispatches
 ADD CONSTRAINT chk_krim_workflow_dispatch_attempts_nonnegative CHECK (processing_attempts>=0);

CREATE INDEX IF NOT EXISTS idx_krim_workflow_dispatch_retry
 ON public.krim_event_workflow_dispatches(status,next_attempt_at,created_at)
 WHERE status IN ('queued','failed') AND workflow_run_id IS NULL;

CREATE OR REPLACE FUNCTION public.krim_internal_process_workflow_runtime_batch(
 p_worker_id text DEFAULT 'krim-db-cron',p_event_limit integer DEFAULT 25,p_dispatch_limit integer DEFAULT 50,p_action_limit integer DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_event record; v_dispatch record; v_events_processed integer:=0; v_events_failed integer:=0;
 v_dispatches_materialized integer:=0; v_dispatches_failed integer:=0; v_dispatches_retried integer:=0;
 v_action_result jsonb:='{}'::jsonb; v_replay_queue_result jsonb:='{}'::jsonb;
 v_replay_sync_result jsonb:='{}'::jsonb; v_run_reconcile_result jsonb:='{}'::jsonb;
BEGIN
 IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN RAISE EXCEPTION 'worker_id_required'; END IF;
 IF p_event_limit<1 OR p_event_limit>100 OR p_dispatch_limit<1 OR p_dispatch_limit>200 OR p_action_limit<1 OR p_action_limit>100
 THEN RAISE EXCEPTION 'batch_limit_out_of_range'; END IF;

 UPDATE public.krim_events SET processing_status='dead_letter',next_attempt_at=NULL,last_error=coalesce(last_error,'retry_limit_exhausted')
 WHERE processing_status='failed' AND processing_attempts>=5;
 FOR v_event IN SELECT e.event_id FROM public.krim_events e
  WHERE e.processing_status='pending' OR (e.processing_status='failed' AND e.processing_attempts<5 AND coalesce(e.next_attempt_at,e.created_at)<=clock_timestamp())
  ORDER BY coalesce(e.next_attempt_at,e.occurred_at),e.id FOR UPDATE SKIP LOCKED LIMIT p_event_limit
 LOOP
  BEGIN PERFORM public.krim_internal_dispatch_event_to_workflows(v_event.event_id); v_events_processed:=v_events_processed+1;
  EXCEPTION WHEN OTHERS THEN
   UPDATE public.krim_events SET processing_attempts=processing_attempts+1,
    processing_status=CASE WHEN processing_attempts+1>=5 THEN 'dead_letter' ELSE 'failed' END,last_error=left(SQLERRM,2000),
    next_attempt_at=CASE WHEN processing_attempts+1>=5 THEN NULL ELSE clock_timestamp()+make_interval(secs=>least(900,30*(2^least(processing_attempts,4))::integer)) END
   WHERE event_id=v_event.event_id AND processing_status<>'processed'; v_events_failed:=v_events_failed+1;
  END;
 END LOOP;

 FOR v_dispatch IN SELECT d.id,d.processing_attempts FROM public.krim_event_workflow_dispatches d
  WHERE d.workflow_run_id IS NULL AND d.processing_attempts<5
   AND (d.status='queued' OR (d.status='failed' AND coalesce(d.next_attempt_at,d.created_at)<=clock_timestamp()))
  ORDER BY coalesce(d.next_attempt_at,d.created_at),d.id
  FOR UPDATE SKIP LOCKED LIMIT p_dispatch_limit
 LOOP
  UPDATE public.krim_event_workflow_dispatches SET status='matching',last_attempted_at=clock_timestamp(),
   updated_at=clock_timestamp() WHERE id=v_dispatch.id AND workflow_run_id IS NULL;
  BEGIN
   PERFORM public.krim_internal_materialize_workflow_dispatch(v_dispatch.id);
   v_dispatches_materialized:=v_dispatches_materialized+1;
  EXCEPTION WHEN OTHERS THEN
   UPDATE public.krim_event_workflow_dispatches SET status='failed',
    processing_attempts=processing_attempts+1,
    next_attempt_at=CASE WHEN processing_attempts+1>=5 THEN NULL
     ELSE clock_timestamp()+make_interval(secs=>least(900,30*(2^least(processing_attempts,4))::integer)) END,
    failure_code=SQLSTATE,failure_reason=left(SQLERRM,1000),updated_at=clock_timestamp()
   WHERE id=v_dispatch.id AND workflow_run_id IS NULL;
   v_dispatches_failed:=v_dispatches_failed+1;
   IF v_dispatch.processing_attempts<4 THEN v_dispatches_retried:=v_dispatches_retried+1; END IF;
  END;
 END LOOP;

 v_replay_queue_result:=public.krim_internal_process_workflow_dead_letter_replays(10);
 v_action_result:=public.krim_internal_process_workflow_action_batch(p_worker_id,p_action_limit,300);
 v_replay_sync_result:=public.krim_internal_sync_workflow_dead_letter_replays(50);
 v_run_reconcile_result:=public.krim_internal_reconcile_workflow_runs(100);
 RETURN jsonb_build_object('ok',true,'worker_id',p_worker_id,'events_processed',v_events_processed,
  'events_failed',v_events_failed,'dispatches_materialized',v_dispatches_materialized,
  'dispatches_failed',v_dispatches_failed,'dispatches_retried',v_dispatches_retried,
  'actions',v_action_result,'dead_letter_replay_queue',v_replay_queue_result,
  'dead_letter_replay_sync',v_replay_sync_result,'workflow_run_reconciliation',v_run_reconcile_result,
  'processed_at',clock_timestamp());
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) TO service_role;