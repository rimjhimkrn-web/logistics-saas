-- Phase 00: enforce a monotonic partner-assignment lifecycle.
CREATE OR REPLACE FUNCTION private.krim_guard_partner_assignment_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status IN ('rejected','cancelled','completed','failed') THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='A terminal partner assignment cannot be reopened or changed';
  END IF;

  IF NOT (
    (OLD.status='offered' AND NEW.status IN ('accepted','rejected','cancelled')) OR
    (OLD.status='accepted' AND NEW.status IN ('active','cancelled','failed')) OR
    (OLD.status='active' AND NEW.status IN ('completed','cancelled','failed'))
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Invalid partner assignment status transition';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_guard_partner_assignment_status_transition
 ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_guard_partner_assignment_status_transition
 BEFORE UPDATE OF status ON public.krim_shipment_partner_assignments
 FOR EACH ROW EXECUTE FUNCTION private.krim_guard_partner_assignment_status_transition();

REVOKE ALL ON FUNCTION private.krim_guard_partner_assignment_status_transition()
 FROM PUBLIC,anon,authenticated,service_role;
