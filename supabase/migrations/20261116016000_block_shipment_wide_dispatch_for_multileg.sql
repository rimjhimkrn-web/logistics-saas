-- Prevent the legacy shipment-wide dispatch path from advancing a multi-leg shipment.
-- Multi-leg execution must use an explicit per-leg dispatch lifecycle.
CREATE OR REPLACE FUNCTION private.krim_block_shipment_wide_dispatch_for_multileg()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.status='dispatched' AND OLD.status IS DISTINCT FROM NEW.status
     AND EXISTS (
       SELECT 1
       FROM public.krim_shipment_leg_plans p
       WHERE p.shipment_id=NEW.id
         AND p.status='active'
         AND p.total_legs>1
     ) THEN
    RAISE EXCEPTION USING
      errcode='23514',
      message='Shipment-wide dispatch is disabled for active multi-leg plans; dispatch must be authorised per leg after exact-leg assignment, capacity, driver, vehicle and custody readiness are verified';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_block_shipment_wide_dispatch_for_multileg()
FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_block_shipment_wide_dispatch_multileg ON public.krim_shipments;
CREATE TRIGGER trg_krim_block_shipment_wide_dispatch_multileg
BEFORE UPDATE OF status ON public.krim_shipments
FOR EACH ROW
EXECUTE FUNCTION private.krim_block_shipment_wide_dispatch_for_multileg();
