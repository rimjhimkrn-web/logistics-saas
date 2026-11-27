-- Phase 00: prevent workflow actions from reporting side effects that were never performed.
-- Only noop is currently a real, safe workflow action. Event recording and notification
-- actions remain disabled until they have dedicated, verified persistence/delivery handlers.
CREATE OR REPLACE FUNCTION krim_internal.execute_workflow_queue_item(
  p_queue_lease_id bigint,
  p_worker_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  q public.krim_workflow_queue_leases%rowtype;
  a public.krim_workflow_action_executions%rowtype;
  action_name text;
  result jsonb;
BEGIN
  IF p_worker_id IS NULL OR btrim(p_worker_id) = '' THEN
    RAISE EXCEPTION 'worker_required';
  END IF;

  SELECT *
    INTO q
  FROM public.krim_workflow_queue_leases
  WHERE id = p_queue_lease_id
    AND worker_id = p_worker_id
    AND status = 'leased'
    AND lease_expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_queue_lease_required';
  END IF;

  IF q.action_execution_id IS NULL THEN
    UPDATE public.krim_workflow_queue_leases
    SET status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = q.id;

    RETURN jsonb_build_object(
      'queue_lease_id', q.id,
      'status', 'completed',
      'type', 'workflow_run'
    );
  END IF;

  SELECT *
    INTO a
  FROM public.krim_workflow_action_executions
  WHERE id = q.action_execution_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'action_execution_not_found';
  END IF;

  action_name := lower(coalesce(a.action_type, ''));

  -- Do not claim that notifications or event records were created when they were not.
  -- Those actions must remain failed until their real handlers are implemented.
  IF action_name <> 'noop' THEN
    PERFORM krim_internal.finalize_workflow_action_result(
      a.id,
      p_worker_id,
      'failed',
      '{}'::jsonb,
      'unsupported_action_not_implemented',
      'This action has no verified persistence or delivery handler and is disabled.',
      NULL,
      'exec:' || a.id || ':' || q.attempt_number
    );

    PERFORM krim_internal.propagate_workflow_run_after_action(
      a.id,
      'propagate:' || a.id || ':' || q.attempt_number
    );

    RETURN jsonb_build_object(
      'queue_lease_id', q.id,
      'action_execution_id', a.id,
      'status', 'failed',
      'reason', 'unsupported_action_not_implemented'
    );
  END IF;

  result := jsonb_build_object('action', 'noop', 'executed', true);

  PERFORM krim_internal.finalize_workflow_action_result(
    a.id,
    p_worker_id,
    'succeeded',
    result,
    NULL,
    NULL,
    NULL,
    'exec:' || a.id || ':' || q.attempt_number
  );

  PERFORM krim_internal.propagate_workflow_run_after_action(
    a.id,
    'propagate:' || a.id || ':' || q.attempt_number
  );

  RETURN jsonb_build_object(
    'queue_lease_id', q.id,
    'action_execution_id', a.id,
    'status', 'succeeded',
    'result', result
  );
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.execute_workflow_queue_item(bigint, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION krim_internal.execute_workflow_queue_item(bigint, text)
  TO service_role;
