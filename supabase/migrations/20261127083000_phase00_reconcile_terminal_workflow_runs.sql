CREATE OR REPLACE FUNCTION public.krim_internal_reconcile_workflow_runs(p_limit integer DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_run record; v_completed integer:=0; v_failed integer:=0; v_repaired integer:=0;
 v_has_open boolean; v_has_failed boolean; v_target_status text; v_now timestamptz:=clock_timestamp();
BEGIN
 IF p_limit<1 OR p_limit>500 THEN RAISE EXCEPTION 'reconcile_limit_out_of_range'; END IF;
 FOR v_run IN
  SELECT r.id,r.status,r.completed_at
  FROM public.krim_workflow_runs r
  WHERE r.status='running'
  ORDER BY r.started_at,r.id
  FOR UPDATE SKIP LOCKED LIMIT p_limit
 LOOP
  SELECT
   coalesce(bool_or(s.status IN ('pending','running')),false),
   coalesce(bool_or(s.status='failed'),false)
  INTO v_has_open,v_has_failed
  FROM public.krim_workflow_run_steps s WHERE s.workflow_run_id=v_run.id;

  IF v_has_open THEN CONTINUE; END IF;

  IF v_has_failed THEN v_target_status:='failed'; ELSE v_target_status:='completed'; END IF;

  UPDATE public.krim_workflow_runs
  SET status=v_target_status,completed_at=coalesce(completed_at,v_now),
      error_message=CASE WHEN v_target_status='failed'
        THEN coalesce(error_message,'One or more workflow steps failed or were quarantined.')
        ELSE error_message END,
      result=coalesce(result,'{}'::jsonb)||jsonb_build_object('reconciled_at',v_now,'reconciled_status',v_target_status)
  WHERE id=v_run.id AND status='running';

  IF FOUND THEN
   v_repaired:=v_repaired+1;
   IF v_target_status='completed' THEN v_completed:=v_completed+1;
   ELSE v_failed:=v_failed+1; END IF;
   UPDATE public.krim_event_workflow_dispatches
   SET completed_at=coalesce(completed_at,v_now),updated_at=v_now,
       result_snapshot=coalesce(result_snapshot,'{}'::jsonb)||jsonb_build_object('workflow_run_status',v_target_status)
   WHERE workflow_run_id=v_run.id;
  END IF;
 END LOOP;

 RETURN jsonb_build_object('reconciled',v_repaired,'completed',v_completed,'failed',v_failed,'checked_at',v_now);
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_process_workflow_runtime_batch(
 p_worker_id text DEFAULT 'krim-db-cron',p_event_limit integer DEFAULT 25,
 p_dispatch_limit integer DEFAULT 50,p_action_limit integer DEFAULT 25)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_event record; v_dispatch record; v_events_processed integer:=0; v_events_failed integer:=0;
 v_dispatches_materialized integer:=0; v_dispatches_failed integer:=0;
 v_action_result jsonb:='{}'::jsonb; v_replay_queue_result jsonb:='{}'::jsonb;
 v_replay_sync_result jsonb:='{}'::jsonb; v_run_reconcile_result jsonb:='{}'::jsonb;
BEGIN
 IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN RAISE EXCEPTION 'worker_id_required'; END IF;
 IF p_event_limit<1 OR p_event_limit>100 OR p_dispatch_limit<1 OR p_dispatch_limit>200
  OR p_action_limit<1 OR p_action_limit>100 THEN RAISE EXCEPTION 'batch_limit_out_of_range'; END IF;
 UPDATE public.krim_events SET processing_status='dead_letter',next_attempt_at=NULL,
  last_error=coalesce(last_error,'retry_limit_exhausted')
 WHERE processing_status='failed' AND processing_attempts>=5;
 FOR v_event IN SELECT e.event_id FROM public.krim_events e
  WHERE e.processing_status='pending' OR (e.processing_status='failed' AND e.processing_attempts<5
   AND coalesce(e.next_attempt_at,e.created_at)<=clock_timestamp())
  ORDER BY coalesce(e.next_attempt_at,e.occurred_at),e.id
  FOR UPDATE SKIP LOCKED LIMIT p_event_limit
 LOOP
  BEGIN
   PERFORM public.krim_internal_dispatch_event_to_workflows(v_event.event_id);
   v_events_processed:=v_events_processed+1;
  EXCEPTION WHEN OTHERS THEN
   UPDATE public.krim_events SET processing_attempts=processing_attempts+1,
    processing_status=CASE WHEN processing_attempts+1>=5 THEN 'dead_letter' ELSE 'failed' END,
    last_error=left(SQLERRM,2000),
    next_attempt_at=CASE WHEN processing_attempts+1>=5 THEN NULL
     ELSE clock_timestamp()+make_interval(secs=>least(900,30*(2^least(processing_attempts,4))::integer)) END
   WHERE event_id=v_event.event_id AND processing_status<>'processed';
   v_events_failed:=v_events_failed+1;
  END;
 END LOOP;
 FOR v_dispatch IN SELECT d.id FROM public.krim_event_workflow_dispatches d
  WHERE d.status='queued' AND d.workflow_run_id IS NULL ORDER BY d.created_at,d.id
  FOR UPDATE SKIP LOCKED LIMIT p_dispatch_limit
 LOOP
  BEGIN
   PERFORM public.krim_internal_materialize_workflow_dispatch(v_dispatch.id);
   v_dispatches_materialized:=v_dispatches_materialized+1;
  EXCEPTION WHEN OTHERS THEN
   UPDATE public.krim_event_workflow_dispatches SET status='failed',failure_code=SQLSTATE,
    failure_reason=left(SQLERRM,1000),updated_at=clock_timestamp()
   WHERE id=v_dispatch.id AND workflow_run_id IS NULL;
   v_dispatches_failed:=v_dispatches_failed+1;
  END;
 END LOOP;
 v_replay_queue_result:=public.krim_internal_process_workflow_dead_letter_replays(10);
 v_action_result:=public.krim_internal_process_workflow_action_batch(p_worker_id,p_action_limit,300);
 v_replay_sync_result:=public.krim_internal_sync_workflow_dead_letter_replays(50);
 v_run_reconcile_result:=public.krim_internal_reconcile_workflow_runs(100);
 RETURN jsonb_build_object('ok',true,'worker_id',p_worker_id,'events_processed',v_events_processed,
  'events_failed',v_events_failed,'dispatches_materialized',v_dispatches_materialized,
  'dispatches_failed',v_dispatches_failed,'actions',v_action_result,
  'dead_letter_replay_queue',v_replay_queue_result,'dead_letter_replay_sync',v_replay_sync_result,
  'workflow_run_reconciliation',v_run_reconcile_result,'processed_at',clock_timestamp());
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_reconcile_workflow_runs(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_reconcile_workflow_runs(integer) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) TO service_role;