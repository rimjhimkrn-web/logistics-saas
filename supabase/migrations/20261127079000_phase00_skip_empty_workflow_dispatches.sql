-- Prevent active workflows with no enabled steps from creating permanently running empty runs.
CREATE OR REPLACE FUNCTION public.krim_internal_materialize_workflow_dispatch(p_dispatch_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dispatch record;
  v_workflow record;
  v_step record;
  v_run bigint;
  v_run_step bigint;
  v_action_id bigint;
  v_count integer := 0;
  v_key text;
  v_action_key text;
  v_active_step_count integer := 0;
BEGIN
  SELECT drow.*, e.event_id AS source_event_uuid, e.event_type,
         e.payload AS event_payload
    INTO v_dispatch
  FROM public.krim_event_workflow_dispatches drow
  JOIN public.krim_events e ON e.id = drow.event_id
  WHERE drow.id = p_dispatch_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'dispatch_not_found'; END IF;
  IF v_dispatch.workflow_run_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'dispatch_id', p_dispatch_id,
      'workflow_run_id', v_dispatch.workflow_run_id, 'idempotent', true);
  END IF;

  SELECT * INTO v_workflow
  FROM public.krim_workflows
  WHERE id = (SELECT workflow_id FROM public.krim_workflow_triggers
              WHERE id = v_dispatch.workflow_trigger_id)
    AND status = 'active';

  IF NOT FOUND THEN
    UPDATE public.krim_event_workflow_dispatches
    SET status = 'skipped', match_result = 'invalid',
        failure_code = 'WORKFLOW_INACTIVE',
        failure_reason = 'Workflow is not active', updated_at = clock_timestamp()
    WHERE id = p_dispatch_id;
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'WORKFLOW_INACTIVE');
  END IF;

  SELECT count(*)::integer INTO v_active_step_count
  FROM public.krim_workflow_steps
  WHERE workflow_id = v_workflow.id AND is_active = true;

  IF v_active_step_count = 0 THEN
    UPDATE public.krim_event_workflow_dispatches
    SET status = 'skipped',
        match_result = 'invalid',
        failure_code = 'WORKFLOW_HAS_NO_ACTIVE_STEPS',
        failure_reason = 'Workflow has no active steps; no workflow run was created.',
        updated_at = clock_timestamp(),
        result_snapshot = jsonb_build_object('active_step_count', 0, 'run_created', false)
    WHERE id = p_dispatch_id;
    RETURN jsonb_build_object(
      'ok', true, 'skipped', true,
      'reason', 'WORKFLOW_HAS_NO_ACTIVE_STEPS',
      'run_created', false
    );
  END IF;

  v_key := 'workflow-run:' || v_dispatch.event_id || ':' || v_dispatch.workflow_trigger_id;
  SELECT id INTO v_run FROM public.krim_workflow_runs WHERE idempotency_key = v_key;

  IF v_run IS NULL THEN
    INSERT INTO public.krim_workflow_runs(
      workflow_id, organization_id, entity_type, entity_id, status,
      started_at, context, result, created_at, trigger_event_id, idempotency_key, attempt_count
    )
    VALUES (
      v_workflow.id, v_dispatch.organization_id, v_dispatch.entity_type,
      v_dispatch.entity_id, 'running', clock_timestamp(),
      jsonb_build_object('trigger_event_id', v_dispatch.source_event_uuid,
        'event_id', v_dispatch.source_event_uuid, 'event_type', v_dispatch.event_type,
        'payload', v_dispatch.event_payload),
      '{}'::jsonb, clock_timestamp(), v_dispatch.source_event_uuid, v_key, 0
    )
    RETURNING id INTO v_run;
  END IF;

  FOR v_step IN
    SELECT * FROM public.krim_workflow_steps
    WHERE workflow_id = v_workflow.id AND is_active = true
    ORDER BY step_order
  LOOP
    SELECT id INTO v_run_step
    FROM public.krim_workflow_run_steps
    WHERE workflow_run_id = v_run AND workflow_step_id = v_step.id;

    IF v_run_step IS NULL THEN
      INSERT INTO public.krim_workflow_run_steps(
        workflow_run_id, workflow_step_id, status, attempt_count, created_at
      )
      VALUES (v_run, v_step.id, 'pending', 0, clock_timestamp())
      RETURNING id INTO v_run_step;
    END IF;

    v_action_key := 'workflow-action:' || v_run || ':' || v_step.id;
    SELECT id INTO v_action_id
    FROM public.krim_workflow_action_executions
    WHERE idempotency_key = v_action_key;

    IF v_action_id IS NULL THEN
      INSERT INTO public.krim_workflow_action_executions(
        workflow_run_id, action_sequence, action_type, status, attempt_number,
        max_attempts, timeout_seconds, idempotency_key, request_snapshot,
        scheduled_at, created_at, updated_at
      )
      VALUES (
        v_run, v_step.step_order, coalesce(v_step.action, v_step.step_code),
        'queued', 0, coalesce(v_workflow.retry_limit, 5),
        coalesce(v_workflow.timeout_seconds, 300), v_action_key,
        jsonb_build_object('run_step_id', v_run_step, 'step_id', v_step.id,
          'step_code', v_step.step_code, 'step_type', v_step.step_type,
          'configuration', v_step.configuration, 'condition', v_step.condition),
        clock_timestamp(), clock_timestamp(), clock_timestamp()
      )
      RETURNING id INTO v_action_id;
    END IF;

    v_count := v_count + 1;
  END LOOP;

  SELECT id INTO v_run_step FROM public.krim_workflow_run_steps
  WHERE workflow_run_id = v_run ORDER BY id LIMIT 1;

  UPDATE public.krim_workflow_runs
  SET current_step_id = (
    SELECT workflow_step_id FROM public.krim_workflow_run_steps WHERE id = v_run_step
  )
  WHERE id = v_run;

  UPDATE public.krim_event_workflow_dispatches
  SET workflow_run_id = v_run, status = 'dispatched',
      dispatched_at = coalesce(dispatched_at, clock_timestamp()),
      failure_code = NULL, failure_reason = NULL, updated_at = clock_timestamp(),
      result_snapshot = jsonb_build_object('workflow_run_id', v_run, 'actions_materialized', v_count)
  WHERE id = p_dispatch_id;

  RETURN jsonb_build_object('ok', true, 'dispatch_id', p_dispatch_id,
    'workflow_run_id', v_run, 'actions_materialized', v_count);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_materialize_workflow_dispatch(bigint)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_materialize_workflow_dispatch(bigint)
  TO service_role;