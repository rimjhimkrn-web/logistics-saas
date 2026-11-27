-- Bounded exponential retry for domain-event dispatch failures.
ALTER TABLE public.krim_events
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz;

UPDATE public.krim_events
SET next_attempt_at = coalesce(next_attempt_at, created_at)
WHERE processing_status IN ('pending','failed');

CREATE OR REPLACE FUNCTION public.krim_internal_dispatch_event_to_workflows(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_event public.krim_events%rowtype;
  v_trigger record;
  v_count integer := 0;
  v_key text;
  v_dispatch_id bigint;
  v_next_attempt integer;
BEGIN
  SELECT * INTO v_event
  FROM public.krim_events
  WHERE event_id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'event_not_found'; END IF;
  IF v_event.processing_status IN ('processed','dead_letter') THEN
    RETURN jsonb_build_object('ok',true,'event_id',p_event_id,'already_terminal',true,
      'processing_status',v_event.processing_status);
  END IF;

  FOR v_trigger IN
    SELECT wt.id AS trigger_id, wt.workflow_id, wt.event_type, wt.condition, wt.priority,
           w.workflow_code, w.workflow_name, w.version
    FROM public.krim_workflow_triggers wt
    JOIN public.krim_workflows w ON w.id=wt.workflow_id
    WHERE wt.is_active=true AND wt.event_type=v_event.event_type AND w.status='active'
      AND (w.organization_id IS NULL OR w.organization_id=v_event.organization_id)
      AND (wt.condition IS NULL OR wt.condition='{}'::jsonb OR (v_event.payload @> wt.condition))
    ORDER BY wt.priority DESC,wt.id
  LOOP
    v_key := 'event-workflow:'||v_event.id||':'||v_trigger.trigger_id;
    INSERT INTO public.krim_event_workflow_dispatches(
      event_id,workflow_trigger_id,organization_id,entity_type,entity_id,dispatch_number,
      status,match_result,idempotency_key,input_snapshot,created_at,updated_at
    )
    VALUES(
      v_event.id,v_trigger.trigger_id,v_event.organization_id,v_event.entity_type,v_event.entity_id,
      'EWD-'||v_event.id||'-'||v_trigger.trigger_id,'queued','matched',v_key,
      jsonb_build_object('event_id',v_event.event_id,'event_type',v_event.event_type,
        'payload',v_event.payload,'workflow_code',v_trigger.workflow_code,'workflow_version',v_trigger.version),
      now(),now()
    )
    ON CONFLICT(idempotency_key) DO NOTHING
    RETURNING id INTO v_dispatch_id;
    IF v_dispatch_id IS NOT NULL THEN v_count:=v_count+1; END IF;
    v_dispatch_id := NULL;
  END LOOP;

  UPDATE public.krim_events
  SET processing_status='processed',processed_at=now(),
      processing_attempts=processing_attempts+1,last_error=NULL,next_attempt_at=NULL
  WHERE id=v_event.id;

  RETURN jsonb_build_object('ok',true,'event_id',p_event_id,'dispatches_created',v_count,
    'no_matching_workflow',v_count=0);
EXCEPTION WHEN OTHERS THEN
  v_next_attempt := coalesce(v_event.processing_attempts,0)+1;
  UPDATE public.krim_events
  SET processing_status=CASE WHEN v_next_attempt>=5 THEN 'dead_letter' ELSE 'failed' END,
      processing_attempts=v_next_attempt,
      last_error=left(SQLERRM,2000),
      next_attempt_at=CASE WHEN v_next_attempt>=5 THEN NULL
        ELSE clock_timestamp() + make_interval(secs => least(900,30 * (2 ^ least(v_next_attempt-1,4))::integer)) END
  WHERE event_id=p_event_id;
  RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_process_workflow_runtime_batch(
  p_worker_id text DEFAULT 'krim-db-cron',
  p_event_limit integer DEFAULT 25,
  p_dispatch_limit integer DEFAULT 50,
  p_action_limit integer DEFAULT 25
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_event record;
  v_dispatch record;
  v_events_processed integer := 0;
  v_events_failed integer := 0;
  v_dispatches_materialized integer := 0;
  v_dispatches_failed integer := 0;
  v_action_result jsonb := '{}'::jsonb;
  v_replay_queue_result jsonb := '{}'::jsonb;
  v_replay_sync_result jsonb := '{}'::jsonb;
BEGIN
  IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN RAISE EXCEPTION 'worker_id_required'; END IF;
  IF p_event_limit<1 OR p_event_limit>100 OR p_dispatch_limit<1 OR p_dispatch_limit>200
     OR p_action_limit<1 OR p_action_limit>100 THEN RAISE EXCEPTION 'batch_limit_out_of_range'; END IF;

  -- Move exhausted historical failures to terminal dead-letter state.
  UPDATE public.krim_events
  SET processing_status='dead_letter',next_attempt_at=NULL,
      last_error=coalesce(last_error,'retry_limit_exhausted')
  WHERE processing_status='failed' AND processing_attempts>=5;

  -- Retry due failed events; row locks prevent concurrent workers from claiming the same event.
  FOR v_event IN
    SELECT e.event_id
    FROM public.krim_events e
    WHERE (e.processing_status='pending'
       OR (e.processing_status='failed' AND e.processing_attempts<5
           AND coalesce(e.next_attempt_at,e.created_at)<=clock_timestamp()))
    ORDER BY coalesce(e.next_attempt_at,e.occurred_at),e.id
    FOR UPDATE SKIP LOCKED
    LIMIT p_event_limit
  LOOP
    BEGIN
      PERFORM public.krim_internal_dispatch_event_to_workflows(v_event.event_id);
      v_events_processed:=v_events_processed+1;
    EXCEPTION WHEN OTHERS THEN
      v_events_failed:=v_events_failed+1;
    END;
  END LOOP;

  FOR v_dispatch IN
    SELECT d.id FROM public.krim_event_workflow_dispatches d
    WHERE d.status='queued' AND d.workflow_run_id IS NULL
    ORDER BY d.created_at,d.id
    FOR UPDATE SKIP LOCKED LIMIT p_dispatch_limit
  LOOP
    BEGIN
      PERFORM public.krim_internal_materialize_workflow_dispatch(v_dispatch.id);
      v_dispatches_materialized:=v_dispatches_materialized+1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.krim_event_workflow_dispatches
      SET status='failed',failure_code=SQLSTATE,failure_reason=left(SQLERRM,1000),
          updated_at=clock_timestamp()
      WHERE id=v_dispatch.id AND workflow_run_id IS NULL;
      v_dispatches_failed:=v_dispatches_failed+1;
    END;
  END LOOP;

  v_replay_queue_result:=public.krim_internal_process_workflow_dead_letter_replays(10);
  v_action_result:=public.krim_internal_process_workflow_action_batch(p_worker_id,p_action_limit,300);
  v_replay_sync_result:=public.krim_internal_sync_workflow_dead_letter_replays(50);

  RETURN jsonb_build_object('ok',true,'worker_id',p_worker_id,
    'events_processed',v_events_processed,'events_failed',v_events_failed,
    'dispatches_materialized',v_dispatches_materialized,'dispatches_failed',v_dispatches_failed,
    'actions',v_action_result,'dead_letter_replay_queue',v_replay_queue_result,
    'dead_letter_replay_sync',v_replay_sync_result,'processed_at',clock_timestamp());
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_dispatch_event_to_workflows(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_dispatch_event_to_workflows(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_process_workflow_runtime_batch(text,integer,integer,integer) TO service_role;