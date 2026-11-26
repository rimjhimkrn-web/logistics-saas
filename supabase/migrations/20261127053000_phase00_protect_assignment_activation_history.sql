-- Preserve partner-assignment activation and event history.
CREATE OR REPLACE FUNCTION private.krim_block_assignment_activation_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'assignment_activation_history_is_immutable';
END;
$$;

CREATE OR REPLACE FUNCTION private.krim_block_assignment_activation_history_truncate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'assignment_activation_history_truncate_forbidden';
END;
$$;

DROP TRIGGER IF EXISTS trg_krim_activation_no_delete ON public.krim_partner_assignment_activations;
CREATE TRIGGER trg_krim_activation_no_delete
BEFORE DELETE ON public.krim_partner_assignment_activations
FOR EACH ROW EXECUTE FUNCTION private.krim_block_assignment_activation_history_mutation();

DROP TRIGGER IF EXISTS trg_krim_activation_no_truncate ON public.krim_partner_assignment_activations;
CREATE TRIGGER trg_krim_activation_no_truncate
BEFORE TRUNCATE ON public.krim_partner_assignment_activations
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_assignment_activation_history_truncate();

DROP TRIGGER IF EXISTS trg_krim_activation_event_immutable ON public.krim_partner_assignment_activation_events;
CREATE TRIGGER trg_krim_activation_event_immutable
BEFORE UPDATE OR DELETE ON public.krim_partner_assignment_activation_events
FOR EACH ROW EXECUTE FUNCTION private.krim_block_assignment_activation_history_mutation();

DROP TRIGGER IF EXISTS trg_krim_activation_event_no_truncate ON public.krim_partner_assignment_activation_events;
CREATE TRIGGER trg_krim_activation_event_no_truncate
BEFORE TRUNCATE ON public.krim_partner_assignment_activation_events
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_assignment_activation_history_truncate();

REVOKE ALL ON FUNCTION private.krim_block_assignment_activation_history_mutation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.krim_block_assignment_activation_history_truncate() FROM PUBLIC, anon, authenticated, service_role;
REVOKE DELETE, TRUNCATE ON public.krim_partner_assignment_activations FROM anon, authenticated, service_role;
REVOKE UPDATE, DELETE, TRUNCATE ON public.krim_partner_assignment_activation_events FROM anon, authenticated, service_role;
