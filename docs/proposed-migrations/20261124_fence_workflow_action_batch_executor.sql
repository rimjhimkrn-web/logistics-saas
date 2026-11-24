-- PROPOSED ONLY. Replaces the live batch processor's direct executor call
-- with the lease-fenced bridge. Do not apply until disposable-DB integration
-- tests cover this full function and production migration history is reconciled.

create or replace function public.krim_internal_process_workflow_action_batch(
  p_worker_id text,
  p_limit integer default 10,
  p_lease_seconds integer default 300
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $function$
declare
  v_claim record;
  v_result jsonb;
  v_processed integer := 0;
  v_succeeded integer := 0;
  v_failed integer := 0;
  v_recovered integer := 0;
  v_attempt integer;
  v_max_attempts integer;
  v_run_step_id bigint;
  v_error_code text;
  v_error_message text;
  v_sqlstate text;
  v_dead_letter_id bigint;
begin
  if p_worker_id is null or btrim(p_worker_id) = '' then
    raise exception 'worker_id required';
  end if;

  v_recovered := public.krim_internal_recover_expired_workflow_actions(100);

  for v_claim in
    select * from public.krim_internal_claim_workflow_actions(p_worker_id, p_limit, p_lease_seconds)
  loop
    v_processed := v_processed + 1;

    begin
      -- Critical change: bind execution to the exact lease returned by claim.
      v_result := krim_internal.execute_workflow_action_fenced(
        v_claim.action_execution_id,
        v_claim.lease_id,
        p_worker_id
      );

      if coalesce(v_result->>'status', '') = 'succeeded'
         or coalesce(v_result->>'success', 'false') = 'true' then
        -- Release only this claim's lease. A later worker cannot be cleared.
        update public.krim_workflow_action_executions
        set lease_id = null, lease_expires_at = null, updated_at = clock_timestamp()
        where id = v_claim.action_execution_id
          and status = 'succeeded'
          and lease_id = v_claim.lease_id
          and request_snapshot->>'worker_id' = p_worker_id;
        v_succeeded := v_succeeded + 1;
      else
        v_failed := v_failed + 1;
        v_error_code := coalesce(v_result->>'error_code', 'ACTION_FAILED');
        v_error_message := coalesce(v_result->>'error_message', 'Workflow action returned a non-success result.');
        select attempt_number, max_attempts, (request_snapshot->>'run_step_id')::bigint
          into v_attempt, v_max_attempts, v_run_step_id
        from public.krim_workflow_action_executions
        where id = v_claim.action_execution_id
          and lease_id = v_claim.lease_id
          and request_snapshot->>'worker_id' = p_worker_id;

        if not found then
          raise exception 'workflow_action_lease_lost_before_failure_handling';
        end if;

        if v_error_code = 'UNSUPPORTED_ACTION' or v_attempt >= v_max_attempts then
          update public.krim_workflow_action_executions
          set status = 'failed', error_code = v_error_code,
              error_message = left(v_error_message, 1000),
              dead_lettered_at = coalesce(dead_lettered_at, clock_timestamp()),
              lease_id = null, lease_expires_at = null, updated_at = clock_timestamp()
          where id = v_claim.action_execution_id
            and lease_id = v_claim.lease_id
            and request_snapshot->>'worker_id' = p_worker_id;

          update public.krim_workflow_run_steps
          set status = 'failed', error_message = left(v_error_message, 1000),
              completed_at = clock_timestamp()
          where id = v_run_step_id;

          v_dead_letter_id := public.krim_internal_quarantine_workflow_action(
            v_claim.action_execution_id,
            case when v_error_code = 'UNSUPPORTED_ACTION' then 'permanent_error' else 'max_attempts' end
          );
        else
          update public.krim_workflow_action_executions
          set status = 'retry_wait',
              next_retry_at = clock_timestamp() + make_interval(secs => least(300, greatest(10, v_attempt * 30))),
              error_code = v_error_code,
              error_message = left(v_error_message, 1000),
              lease_id = null, lease_expires_at = null, updated_at = clock_timestamp()
          where id = v_claim.action_execution_id
            and lease_id = v_claim.lease_id
            and request_snapshot->>'worker_id' = p_worker_id;

          update public.krim_workflow_run_steps
          set status = 'pending', error_message = null, completed_at = null
          where id = v_run_step_id;
        end if;
      end if;
    exception when others then
      v_failed := v_failed + 1;
      v_sqlstate := sqlstate;
      v_error_message := left(sqlerrm, 1000);

      select attempt_number, max_attempts, (request_snapshot->>'run_step_id')::bigint
        into v_attempt, v_max_attempts, v_run_step_id
      from public.krim_workflow_action_executions
      where id = v_claim.action_execution_id
        and lease_id = v_claim.lease_id
          and request_snapshot->>'worker_id' = p_worker_id;

      if not found then
        -- Lease was replaced; stale worker must not mutate the new owner's row.
        continue;
      end if;

      v_error_code := coalesce(v_sqlstate, 'WORKFLOW_ACTION_ERROR');

      if v_attempt >= v_max_attempts then
        update public.krim_workflow_action_executions
        set status = 'failed', next_retry_at = null,
            dead_lettered_at = coalesce(dead_lettered_at, clock_timestamp()),
            error_code = v_error_code, error_message = v_error_message,
            lease_id = null, lease_expires_at = null, updated_at = clock_timestamp()
        where id = v_claim.action_execution_id
          and lease_id = v_claim.lease_id
          and request_snapshot->>'worker_id' = p_worker_id;

        update public.krim_workflow_run_steps
        set status = 'failed', error_message = v_error_message,
            completed_at = clock_timestamp()
        where id = v_run_step_id;

        v_dead_letter_id := public.krim_internal_quarantine_workflow_action(
          v_claim.action_execution_id, 'max_attempts'
        );
      else
        update public.krim_workflow_action_executions
        set status = 'retry_wait',
            next_retry_at = clock_timestamp() + make_interval(secs => least(300, greatest(10, v_attempt * 30))),
            error_code = v_error_code, error_message = v_error_message,
            lease_id = null, lease_expires_at = null, updated_at = clock_timestamp()
        where id = v_claim.action_execution_id
          and lease_id = v_claim.lease_id
          and request_snapshot->>'worker_id' = p_worker_id;

        update public.krim_workflow_run_steps
        set status = 'pending', error_message = null, completed_at = null
        where id = v_run_step_id;
      end if;
    end;
  end loop;

  return jsonb_build_object(
    'worker_id', p_worker_id,
    'processed', v_processed,
    'succeeded', v_succeeded,
    'failed', v_failed,
    'recovered_expired', v_recovered,
    'processed_at', clock_timestamp()
  );
end;
$function$;
