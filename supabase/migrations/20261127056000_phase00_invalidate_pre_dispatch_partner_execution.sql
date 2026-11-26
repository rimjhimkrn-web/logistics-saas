CREATE OR REPLACE FUNCTION private.krim_sync_pre_dispatch_partner_assignment_terminal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status
     OR NEW.status NOT IN ('cancelled','failed')
     OR OLD.status NOT IN ('accepted','active') THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.krim_driver_assignments da
    WHERE da.partner_assignment_id=OLD.id
      AND da.shipment_id=OLD.shipment_id
      AND da.shipment_leg_id=OLD.shipment_leg_id
      AND da.organization_id=OLD.partner_organization_id
      AND da.status NOT IN ('assigned','accepted','cancelled')
  ) OR EXISTS (
    SELECT 1
    FROM public.krim_driver_assignments da
    JOIN public.krim_driver_trip_events e ON e.assignment_id=da.id
    WHERE da.partner_assignment_id=OLD.id
      AND da.shipment_id=OLD.shipment_id
      AND da.shipment_leg_id=OLD.shipment_leg_id
      AND da.organization_id=OLD.partner_organization_id
      AND e.event_type IN ('pickup','in_transit')
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Partner assignment has driver execution activity; manual exception/delivery lifecycle is required';
  END IF;

  UPDATE public.krim_shipment_leg_dispatch_authorizations
  SET status='revoked',
      revoked_at=pg_catalog.now(),
      revoked_by=NULL,
      revocation_reason='Partner assignment became '||NEW.status||' before pickup; authorization automatically invalidated'
  WHERE partner_assignment_id=OLD.id
    AND shipment_id=OLD.shipment_id
    AND shipment_leg_id=OLD.shipment_leg_id
    AND partner_organization_id=OLD.partner_organization_id
    AND status='authorized';

  UPDATE public.krim_driver_assignments
  SET status='cancelled',
      updated_at=pg_catalog.now()
  WHERE partner_assignment_id=OLD.id
    AND shipment_id=OLD.shipment_id
    AND shipment_leg_id=OLD.shipment_leg_id
    AND organization_id=OLD.partner_organization_id
    AND status IN ('assigned','accepted');

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_sync_pre_dispatch_partner_assignment_terminal() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_sync_pre_dispatch_partner_assignment_terminal
ON public.krim_shipment_partner_assignments;

CREATE TRIGGER trg_krim_sync_pre_dispatch_partner_assignment_terminal
AFTER UPDATE OF status ON public.krim_shipment_partner_assignments
FOR EACH ROW
EXECUTE FUNCTION private.krim_sync_pre_dispatch_partner_assignment_terminal();
