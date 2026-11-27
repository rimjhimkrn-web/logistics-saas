-- Prevent the active workflow runtime from marking notification preparation as success
-- when no notification/outbox record is actually created.
CREATE OR REPLACE FUNCTION public.krim_internal_execute_workflow_action(p_action_execution_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record;
  rs record;
  v_now timestamptz := clock_timestamp();
  v_payload jsonb;
  v_shipment_id bigint;
  v_exception_id bigint;
BEGIN
  SELECT ae.*, wr.entity_type, wr.entity_id, wr.organization_id, wr.trigger_event_id
    INTO a
  FROM public.krim_workflow_action_executions ae
  JOIN public.krim_workflow_runs wr ON wr.id = ae.workflow_run_id
  WHERE ae.id = p_action_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'action_execution_not_found'; END IF;
  IF a.status = 'succeeded' THEN
    RETURN jsonb_build_object('ok', true, 'idempotent', true, 'action_execution_id', p_action_execution_id);
  END IF;

  SELECT * INTO rs
  FROM public.krim_workflow_run_steps
  WHERE id = ((a.request_snapshot->>'run_step_id')::bigint)
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'workflow_run_step_not_found'; END IF;

  SELECT payload INTO v_payload
  FROM public.krim_events
  WHERE event_id = a.trigger_event_id;
  v_shipment_id := coalesce((v_payload->>'shipment_id')::bigint, a.entity_id);

  UPDATE public.krim_workflow_action_executions
  SET status = 'running',
      attempt_number = attempt_number + 1,
      started_at = coalesce(started_at, v_now),
      updated_at = v_now
  WHERE id = p_action_execution_id;

  IF a.action_type = 'record_workflow_checkpoint' THEN
    UPDATE public.krim_workflow_run_steps
    SET status = 'completed',
        attempt_count = greatest(attempt_count, a.attempt_number),
        started_at = coalesce(started_at, v_now),
        completed_at = v_now,
        result = jsonb_build_object('checkpoint', 'recorded', 'at', v_now)
    WHERE id = rs.id;
    UPDATE public.krim_workflow_action_executions
    SET status = 'succeeded', completed_at = v_now,
        response_snapshot = jsonb_build_object('checkpoint', 'recorded', 'at', v_now),
        updated_at = v_now
    WHERE id = a.id;

  ELSIF a.action_type = 'create_exception_case' THEN
    SELECT id INTO v_exception_id
    FROM public.krim_exceptions
    WHERE shipment_id = v_shipment_id
      AND exception_code = 'SHIPMENT_STATUS_EXCEPTION'
      AND metadata->>'source_action_execution_id' = a.id::text
    LIMIT 1;

    IF v_exception_id IS NULL THEN
      INSERT INTO public.krim_exceptions(
        organization_id, shipment_id, exception_code, exception_type, severity,
        status, detected_at, description, metadata, created_at, updated_at
      )
      VALUES (
        a.organization_id, v_shipment_id, 'SHIPMENT_STATUS_EXCEPTION',
        'operational', 'high', 'open', v_now,
        'Shipment entered exception status.',
        jsonb_build_object('source_action_execution_id', a.id, 'trigger_event_id', a.trigger_event_id),
        v_now, v_now
      )
      RETURNING id INTO v_exception_id;
    END IF;

    UPDATE public.krim_workflow_run_steps
    SET status = 'completed',
        attempt_count = greatest(attempt_count, a.attempt_number),
        started_at = coalesce(started_at, v_now),
        completed_at = v_now,
        result = jsonb_build_object('exception_id', v_exception_id)
    WHERE id = rs.id;
    UPDATE public.krim_workflow_action_executions
    SET status = 'succeeded', completed_at = v_now,
        response_snapshot = jsonb_build_object('exception_id', v_exception_id),
        updated_at = v_now
    WHERE id = a.id;

  ELSIF a.action_type = 'evaluate_delay_risk' THEN
    UPDATE public.krim_workflow_run_steps
    SET status = 'completed',
        attempt_count = greatest(attempt_count, a.attempt_number),
        started_at = coalesce(started_at, v_now),
        completed_at = v_now,
        result = jsonb_build_object('status', 'awaiting_operational_eta_or_tracking_evidence')
    WHERE id = rs.id;
    UPDATE public.krim_workflow_action_executions
    SET status = 'succeeded', completed_at = v_now,
        response_snapshot = jsonb_build_object(
          'status', 'awaiting_operational_eta_or_tracking_evidence',
          'external_prediction_not_used', true
        ),
        updated_at = v_now
    WHERE id = a.id;

  ELSIF a.action_type IN ('prepare_customer_notification', 'prepare_partner_notification') THEN
    UPDATE public.krim_workflow_run_steps
    SET status = 'failed',
        attempt_count = greatest(attempt_count, a.attempt_number),
        error_message = 'Notification action disabled: no verified record-enqueue handler.'
    WHERE id = rs.id;
    UPDATE public.krim_workflow_action_executions
    SET status = 'failed',
        error_code = 'UNSUPPORTED_ACTION',
        error_message = 'Notification action disabled: no verified record-enqueue handler.',
        updated_at = v_now
    WHERE id = a.id;
    RETURN jsonb_build_object(
      'ok', false,
      'status', 'failed',
      'error_code', 'UNSUPPORTED_ACTION',
      'error_message', 'Notification action has no verified record-enqueue handler.'
    );

  ELSE
    UPDATE public.krim_workflow_run_steps
    SET status = 'failed',
        attempt_count = greatest(attempt_count, a.attempt_number),
        error_message = 'No approved executor for action type'
    WHERE id = rs.id;
    UPDATE public.krim_workflow_action_executions
    SET status = 'failed',
        error_code = 'UNSUPPORTED_ACTION',
        error_message = 'No approved executor for action type',
        updated_at = v_now
    WHERE id = a.id;
    RETURN jsonb_build_object('ok', false, 'status', 'failed', 'error_code', 'UNSUPPORTED_ACTION');
  END IF;

  UPDATE public.krim_workflow_runs
  SET status = 'completed',
      completed_at = v_now,
      result = jsonb_build_object('last_action', a.action_type)
  WHERE id = a.workflow_run_id
    AND NOT EXISTS (
      SELECT 1 FROM public.krim_workflow_run_steps
      WHERE workflow_run_id = a.workflow_run_id
        AND status IN ('pending', 'running', 'failed')
    );

  RETURN jsonb_build_object(
    'ok', true,
    'action_execution_id', a.id,
    'status', 'succeeded',
    'action_type', a.action_type
  );

EXCEPTION WHEN OTHERS THEN
  UPDATE public.krim_workflow_action_executions
  SET status = 'failed',
      error_code = 'WORKFLOW_ACTION_ERROR',
      error_message = sqlerrm,
      updated_at = now()
  WHERE id = p_action_execution_id;
  RAISE;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_execute_workflow_action(bigint)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_execute_workflow_action(bigint)
  TO service_role;