-- Prevent live workflow configuration edits from changing queued dispatches or active runs.
CREATE OR REPLACE FUNCTION public.krim_guard_workflow_configuration_during_execution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_workflow_id bigint;
  v_config_id bigint;
  v_blocked boolean := false;
BEGIN
  IF TG_TABLE_NAME = 'krim_workflows' THEN
    v_workflow_id := OLD.id;
    SELECT EXISTS (
      SELECT 1 FROM public.krim_event_workflow_dispatches d
      JOIN public.krim_workflow_triggers t ON t.id=d.workflow_trigger_id
      WHERE t.workflow_id=v_workflow_id AND d.workflow_run_id IS NULL
        AND d.status IN ('queued','matching','failed') AND d.processing_attempts < 5
    ) OR EXISTS (
      SELECT 1 FROM public.krim_workflow_runs r
      WHERE r.workflow_id=v_workflow_id AND r.status='running'
    ) INTO v_blocked;
  ELSIF TG_TABLE_NAME = 'krim_workflow_triggers' THEN
    v_workflow_id := OLD.workflow_id;
    SELECT EXISTS (
      SELECT 1 FROM public.krim_event_workflow_dispatches d
      WHERE d.workflow_trigger_id=OLD.id AND d.workflow_run_id IS NULL
        AND d.status IN ('queued','matching','failed') AND d.processing_attempts < 5
    ) OR EXISTS (
      SELECT 1 FROM public.krim_workflow_runs r
      WHERE r.workflow_id=v_workflow_id AND r.status='running'
    ) INTO v_blocked;
  ELSIF TG_TABLE_NAME = 'krim_workflow_steps' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.krim_workflow_runs r
      JOIN public.krim_workflow_run_steps rs ON rs.workflow_run_id=r.id
      WHERE rs.workflow_step_id=OLD.id AND r.status='running'
    ) INTO v_blocked;
  END IF;

  IF v_blocked THEN
    RAISE EXCEPTION 'workflow_configuration_in_use'
      USING ERRCODE='55000',
            HINT='Wait for queued dispatches and active workflow runs to finish before changing this configuration.';
  END IF;

  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.krim_guard_workflow_configuration_during_execution() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_workflows_execution_guard ON public.krim_workflows;
CREATE TRIGGER trg_krim_workflows_execution_guard
BEFORE UPDATE OR DELETE ON public.krim_workflows
FOR EACH ROW EXECUTE FUNCTION public.krim_guard_workflow_configuration_during_execution();

DROP TRIGGER IF EXISTS trg_krim_workflow_triggers_execution_guard ON public.krim_workflow_triggers;
CREATE TRIGGER trg_krim_workflow_triggers_execution_guard
BEFORE UPDATE OR DELETE ON public.krim_workflow_triggers
FOR EACH ROW EXECUTE FUNCTION public.krim_guard_workflow_configuration_during_execution();

DROP TRIGGER IF EXISTS trg_krim_workflow_steps_execution_guard ON public.krim_workflow_steps;
CREATE TRIGGER trg_krim_workflow_steps_execution_guard
BEFORE UPDATE OR DELETE ON public.krim_workflow_steps
FOR EACH ROW EXECUTE FUNCTION public.krim_guard_workflow_configuration_during_execution();

CREATE OR REPLACE FUNCTION public.krim_block_workflow_configuration_truncate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'workflow_configuration_truncate_blocked'
    USING ERRCODE='55000';
END;
$$;
REVOKE ALL ON FUNCTION public.krim_block_workflow_configuration_truncate() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_workflows_no_truncate ON public.krim_workflows;
CREATE TRIGGER trg_krim_workflows_no_truncate BEFORE TRUNCATE ON public.krim_workflows
FOR EACH STATEMENT EXECUTE FUNCTION public.krim_block_workflow_configuration_truncate();
DROP TRIGGER IF EXISTS trg_krim_workflow_triggers_no_truncate ON public.krim_workflow_triggers;
CREATE TRIGGER trg_krim_workflow_triggers_no_truncate BEFORE TRUNCATE ON public.krim_workflow_triggers
FOR EACH STATEMENT EXECUTE FUNCTION public.krim_block_workflow_configuration_truncate();
DROP TRIGGER IF EXISTS trg_krim_workflow_steps_no_truncate ON public.krim_workflow_steps;
CREATE TRIGGER trg_krim_workflow_steps_no_truncate BEFORE TRUNCATE ON public.krim_workflow_steps
FOR EACH STATEMENT EXECUTE FUNCTION public.krim_block_workflow_configuration_truncate();
