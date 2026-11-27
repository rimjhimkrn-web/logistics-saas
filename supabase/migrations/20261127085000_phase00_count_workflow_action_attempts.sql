-- Count every actual action claim so retries and lease-expiry recovery are bounded.
CREATE OR REPLACE FUNCTION public.krim_internal_claim_workflow_actions(
  p_worker_id text,
  p_limit integer DEFAULT 10,
  p_lease_seconds integer DEFAULT 300
)
RETURNS TABLE(action_execution_id bigint, lease_id uuid, action_type text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit,10),1),100);
  v_default_lease integer := least(greatest(coalesce(p_lease_seconds,300),30),3600);
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN
    RAISE EXCEPTION 'worker_id_required';
  END IF;
  RETURN QUERY
  WITH candidates AS (
    SELECT ae.id
    FROM public.krim_workflow_action_executions ae
    WHERE (
      ae.status='queued'
      OR (ae.status='retry_wait' AND coalesce(ae.next_retry_at,v_now)<=v_now)
      OR (ae.status='running' AND ae.lease_expires_at<=v_now)
    )
    AND (ae.lease_expires_at IS NULL OR ae.lease_expires_at<=v_now)
    AND ae.attempt_number < ae.max_attempts
    ORDER BY ae.scheduled_at NULLS FIRST,ae.created_at,ae.id
    FOR UPDATE SKIP LOCKED
    LIMIT v_limit
  ),
  claimed AS (
    UPDATE public.krim_workflow_action_executions ae
    SET status='running',
        attempt_number=ae.attempt_number+1,
        lease_id=gen_random_uuid(),
        lease_expires_at=v_now+make_interval(secs=>least(3600,greatest(30,coalesce(ae.timeout_seconds,v_default_lease)))),
        started_at=coalesce(ae.started_at,v_now),
        next_retry_at=NULL,
        updated_at=v_now,
        request_snapshot=coalesce(ae.request_snapshot,'{}'::jsonb)
          || jsonb_build_object('worker_id',p_worker_id,'claimed_at',v_now,'claim_attempt',ae.attempt_number+1)
    FROM candidates c
    WHERE ae.id=c.id
    RETURNING ae.id AS claimed_id,ae.lease_id AS claimed_lease_id,ae.action_type AS claimed_action_type
  )
  SELECT c.claimed_id,c.claimed_lease_id,c.claimed_action_type FROM claimed c;
END;
$$;
REVOKE ALL ON FUNCTION public.krim_internal_claim_workflow_actions(text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_claim_workflow_actions(text,integer,integer) TO service_role;
