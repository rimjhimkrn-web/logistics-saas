-- Require the current unexpired action lease at the executor boundary.
CREATE OR REPLACE FUNCTION public.krim_internal_execute_workflow_action(p_action_execution_id bigint,p_lease_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE a record; rs record; v_now timestamptz:=clock_timestamp(); v_payload jsonb;
 v_shipment_id bigint; v_exception_id bigint;
BEGIN
 SELECT ae.*,wr.entity_type,wr.entity_id,wr.organization_id,wr.trigger_event_id INTO a
 FROM public.krim_workflow_action_executions ae JOIN public.krim_workflow_runs wr ON wr.id=ae.workflow_run_id
 WHERE ae.id=p_action_execution_id FOR UPDATE OF ae;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'status','rejected','error_code','ACTION_NOT_FOUND'); END IF;
 IF p_lease_id IS NULL OR a.lease_id IS DISTINCT FROM p_lease_id OR a.lease_expires_at IS NULL
   OR a.lease_expires_at<=v_now OR a.status IS DISTINCT FROM 'running' THEN
  RETURN jsonb_build_object('ok',false,'status','rejected','error_code','STALE_OR_INVALID_LEASE');
 END IF;
 IF a.status='succeeded' THEN RETURN jsonb_build_object('ok',true,'idempotent',true,
   'action_execution_id',p_action_execution_id,'status','succeeded'); END IF;
 SELECT * INTO rs FROM public.krim_workflow_run_steps WHERE id=((a.request_snapshot->>'run_step_id')::bigint) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'workflow_run_step_not_found'; END IF;
 SELECT payload INTO v_payload FROM public.krim_events WHERE event_id=a.trigger_event_id;
 v_shipment_id:=coalesce((v_payload->>'shipment_id')::bigint,a.entity_id);
 IF a.action_type='record_workflow_checkpoint' THEN
  UPDATE public.krim_workflow_run_steps SET status='completed',attempt_count=greatest(attempt_count,a.attempt_number),
   started_at=coalesce(started_at,v_now),completed_at=v_now,result=jsonb_build_object('checkpoint','recorded','at',v_now)
  WHERE id=rs.id;
  UPDATE public.krim_workflow_action_executions SET status='succeeded',completed_at=v_now,
   response_snapshot=jsonb_build_object('checkpoint','recorded','at',v_now),lease_id=NULL,lease_expires_at=NULL,updated_at=v_now
  WHERE id=a.id AND lease_id=p_lease_id AND lease_expires_at>v_now;
 ELSIF a.action_type='create_exception_case' THEN
  SELECT id INTO v_exception_id FROM public.krim_exceptions WHERE shipment_id=v_shipment_id
   AND exception_code='SHIPMENT_STATUS_EXCEPTION' AND metadata->>'source_action_execution_id'=a.id::text LIMIT 1;
  IF v_exception_id IS NULL THEN
   INSERT INTO public.krim_exceptions(organization_id,shipment_id,exception_code,exception_type,severity,status,
    detected_at,description,metadata,created_at,updated_at)
   VALUES(a.organization_id,v_shipment_id,'SHIPMENT_STATUS_EXCEPTION','operational','high','open',v_now,
    'Shipment entered exception status.',jsonb_build_object('source_action_execution_id',a.id,'trigger_event_id',a.trigger_event_id),v_now,v_now)
   RETURNING id INTO v_exception_id;
  END IF;
  UPDATE public.krim_workflow_run_steps SET status='completed',attempt_count=greatest(attempt_count,a.attempt_number),
   started_at=coalesce(started_at,v_now),completed_at=v_now,result=jsonb_build_object('exception_id',v_exception_id) WHERE id=rs.id;
  UPDATE public.krim_workflow_action_executions SET status='succeeded',completed_at=v_now,
   response_snapshot=jsonb_build_object('exception_id',v_exception_id),lease_id=NULL,lease_expires_at=NULL,updated_at=v_now
  WHERE id=a.id AND lease_id=p_lease_id AND lease_expires_at>v_now;
 ELSIF a.action_type='evaluate_delay_risk' THEN
  UPDATE public.krim_workflow_run_steps SET status='completed',attempt_count=greatest(attempt_count,a.attempt_number),
   started_at=coalesce(started_at,v_now),completed_at=v_now,
   result=jsonb_build_object('status','awaiting_operational_eta_or_tracking_evidence') WHERE id=rs.id;
  UPDATE public.krim_workflow_action_executions SET status='succeeded',completed_at=v_now,
   response_snapshot=jsonb_build_object('status','awaiting_operational_eta_or_tracking_evidence','external_prediction_not_used',true),
   lease_id=NULL,lease_expires_at=NULL,updated_at=v_now WHERE id=a.id AND lease_id=p_lease_id AND lease_expires_at>v_now;
 ELSIF a.action_type IN ('prepare_customer_notification','prepare_partner_notification') THEN
  UPDATE public.krim_workflow_run_steps SET status='failed',attempt_count=greatest(attempt_count,a.attempt_number),
   error_message='Notification action disabled: no verified record-enqueue handler.' WHERE id=rs.id;
  UPDATE public.krim_workflow_action_executions SET status='failed',error_code='UNSUPPORTED_ACTION',
   error_message='Notification action disabled: no verified record-enqueue handler.',lease_id=NULL,lease_expires_at=NULL,updated_at=v_now
  WHERE id=a.id AND lease_id=p_lease_id AND lease_expires_at>v_now;
  RETURN jsonb_build_object('ok',false,'status','failed','error_code','UNSUPPORTED_ACTION',
   'error_message','Notification action has no verified record-enqueue handler.');
 ELSE
  UPDATE public.krim_workflow_run_steps SET status='failed',attempt_count=greatest(attempt_count,a.attempt_number),
   error_message='No approved executor for action type' WHERE id=rs.id;
  UPDATE public.krim_workflow_action_executions SET status='failed',error_code='UNSUPPORTED_ACTION',
   error_message='No approved executor for action type',lease_id=NULL,lease_expires_at=NULL,updated_at=v_now
  WHERE id=a.id AND lease_id=p_lease_id AND lease_expires_at>v_now;
  RETURN jsonb_build_object('ok',false,'status','failed','error_code','UNSUPPORTED_ACTION');
 END IF;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'status','rejected','error_code','LEASE_LOST_DURING_EXECUTION'); END IF;
 UPDATE public.krim_workflow_runs SET status='completed',completed_at=v_now,result=jsonb_build_object('last_action',a.action_type)
 WHERE id=a.workflow_run_id AND NOT EXISTS(SELECT 1 FROM public.krim_workflow_run_steps
  WHERE workflow_run_id=a.workflow_run_id AND status IN ('pending','running','failed'));
 RETURN jsonb_build_object('ok',true,'action_execution_id',a.id,'status','succeeded','action_type',a.action_type);
EXCEPTION WHEN OTHERS THEN
 UPDATE public.krim_workflow_action_executions SET status='failed',error_code='WORKFLOW_ACTION_ERROR',
  error_message=sqlerrm,lease_id=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
 WHERE id=p_action_execution_id AND lease_id=p_lease_id AND lease_expires_at>clock_timestamp();
 RAISE;
END;
$function$;
CREATE OR REPLACE FUNCTION public.krim_internal_execute_workflow_action(p_action_execution_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$ BEGIN RAISE EXCEPTION 'lease_id_required'; END; $function$;

CREATE OR REPLACE FUNCTION public.krim_internal_process_workflow_action_batch(
 p_worker_id text,p_limit integer DEFAULT 10,p_lease_seconds integer DEFAULT 300)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_claim record; v_result jsonb; v_processed integer:=0; v_succeeded integer:=0; v_failed integer:=0;
 v_recovered integer:=0; v_attempt integer; v_max_attempts integer; v_run_step_id bigint;
 v_error_code text; v_error_message text; v_sqlstate text; v_dead_letter_id bigint;
BEGIN
 IF p_worker_id IS NULL OR btrim(p_worker_id)='' THEN RAISE EXCEPTION 'worker_id required'; END IF;
 v_recovered:=public.krim_internal_recover_expired_workflow_actions(100);
 FOR v_claim IN SELECT * FROM public.krim_internal_claim_workflow_actions(p_worker_id,p_limit,p_lease_seconds) LOOP
  v_processed:=v_processed+1;
  BEGIN
   v_result:=public.krim_internal_execute_workflow_action(v_claim.action_execution_id,v_claim.lease_id);
   IF coalesce(v_result->>'status','')='succeeded' OR coalesce(v_result->>'success','false')='true' THEN
    v_succeeded:=v_succeeded+1;
   ELSIF v_result->>'error_code' IN ('STALE_OR_INVALID_LEASE','LEASE_LOST_DURING_EXECUTION') THEN
    v_failed:=v_failed+1;
   ELSE
    v_failed:=v_failed+1; v_error_code:=coalesce(v_result->>'error_code','ACTION_FAILED');
    v_error_message:=coalesce(v_result->>'error_message','Workflow action returned a non-success result.');
    SELECT attempt_number,max_attempts,(request_snapshot->>'run_step_id')::bigint
     INTO v_attempt,v_max_attempts,v_run_step_id FROM public.krim_workflow_action_executions WHERE id=v_claim.action_execution_id;
    IF v_error_code='UNSUPPORTED_ACTION' OR v_attempt>=v_max_attempts THEN
     UPDATE public.krim_workflow_action_executions SET status='failed',error_code=v_error_code,
      error_message=left(v_error_message,1000),dead_lettered_at=coalesce(dead_lettered_at,clock_timestamp()),
      lease_id=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
     WHERE id=v_claim.action_execution_id AND lease_id IS NOT DISTINCT FROM v_claim.lease_id;
     UPDATE public.krim_workflow_run_steps SET status='failed',error_message=left(v_error_message,1000),
      completed_at=clock_timestamp() WHERE id=v_run_step_id;
     v_dead_letter_id:=public.krim_internal_quarantine_workflow_action(v_claim.action_execution_id,
      CASE WHEN v_error_code='UNSUPPORTED_ACTION' THEN 'permanent_error' ELSE 'max_attempts' END);
    ELSE
     UPDATE public.krim_workflow_action_executions SET status='retry_wait',
      next_retry_at=clock_timestamp()+make_interval(secs=>least(300,greatest(10,v_attempt*30))),
      error_code=v_error_code,error_message=left(v_error_message,1000),lease_id=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
     WHERE id=v_claim.action_execution_id AND lease_id IS NOT DISTINCT FROM v_claim.lease_id;
     UPDATE public.krim_workflow_run_steps SET status='pending',error_message=NULL,completed_at=NULL WHERE id=v_run_step_id;
    END IF;
   END IF;
  EXCEPTION WHEN OTHERS THEN
   v_failed:=v_failed+1; v_sqlstate:=SQLSTATE; v_error_message:=left(SQLERRM,1000);
   SELECT attempt_number,max_attempts,(request_snapshot->>'run_step_id')::bigint
    INTO v_attempt,v_max_attempts,v_run_step_id FROM public.krim_workflow_action_executions WHERE id=v_claim.action_execution_id;
   v_error_code:=coalesce(v_sqlstate,'WORKFLOW_ACTION_ERROR');
   IF v_attempt>=v_max_attempts THEN
    UPDATE public.krim_workflow_action_executions SET status='failed',next_retry_at=NULL,
     dead_lettered_at=coalesce(dead_lettered_at,clock_timestamp()),error_code=v_error_code,error_message=v_error_message,
     lease_id=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
    WHERE id=v_claim.action_execution_id AND lease_id=v_claim.lease_id;
    UPDATE public.krim_workflow_run_steps SET status='failed',error_message=v_error_message,
     completed_at=clock_timestamp() WHERE id=v_run_step_id;
    v_dead_letter_id:=public.krim_internal_quarantine_workflow_action(v_claim.action_execution_id,'max_attempts');
   ELSE
    UPDATE public.krim_workflow_action_executions SET status='retry_wait',
     next_retry_at=clock_timestamp()+make_interval(secs=>least(300,greatest(10,v_attempt*30))),
     error_code=v_error_code,error_message=v_error_message,lease_id=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
    WHERE id=v_claim.action_execution_id AND lease_id=v_claim.lease_id;
    UPDATE public.krim_workflow_run_steps SET status='pending',error_message=NULL,completed_at=NULL WHERE id=v_run_step_id;
   END IF;
  END;
 END LOOP;
 RETURN jsonb_build_object('worker_id',p_worker_id,'processed',v_processed,'succeeded',v_succeeded,
  'failed',v_failed,'recovered_expired',v_recovered,'processed_at',clock_timestamp());
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_internal_execute_workflow_action(bigint,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_execute_workflow_action(bigint,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_execute_workflow_action(bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_execute_workflow_action(bigint) TO service_role;
REVOKE ALL ON FUNCTION public.krim_internal_process_workflow_action_batch(text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_process_workflow_action_batch(text,integer,integer) TO service_role;