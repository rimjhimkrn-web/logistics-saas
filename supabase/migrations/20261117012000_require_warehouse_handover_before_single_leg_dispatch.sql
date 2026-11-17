-- Require exact-leg warehouse handover before a shipment-wide dispatch transition.
-- The existing handover predicate validates completed task, picked allocations,
-- no reserved allocations, and private dispatch proof owned by the uploader.
CREATE OR REPLACE FUNCTION private.krim_require_warehouse_handover_before_shipment_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_assignment record;
BEGIN
  IF NEW.status = 'dispatched' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.krim_shipment_partner_assignments a
      WHERE a.shipment_id = NEW.id
        AND a.status IN ('accepted','active')
    ) THEN
      RAISE EXCEPTION USING
        errcode = '23514',
        message = 'Dispatch blocked: an accepted active partner assignment is required';
    END IF;

    FOR v_assignment IN
      SELECT a.id, a.shipment_leg_id, a.partner_organization_id
      FROM public.krim_shipment_partner_assignments a
      WHERE a.shipment_id = NEW.id
        AND a.status IN ('accepted','active')
      ORDER BY a.id
    LOOP
      IF v_assignment.shipment_leg_id IS NULL
         OR v_assignment.partner_organization_id IS NULL
         OR NOT private.krim_dispatch_handover_is_current(
           NEW.id,
           v_assignment.shipment_leg_id,
           v_assignment.partner_organization_id
         ) THEN
        RAISE EXCEPTION USING
          errcode = '23514',
          message = format(
            'Dispatch blocked: partner assignment %s requires completed warehouse handover, picked allocations and current private dispatch proof for its exact shipment leg',
            v_assignment.id
          );
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_require_warehouse_handover_before_shipment_dispatch
ON public.krim_shipments;

CREATE TRIGGER trg_krim_require_warehouse_handover_before_shipment_dispatch
BEFORE UPDATE OF status ON public.krim_shipments
FOR EACH ROW
EXECUTE FUNCTION private.krim_require_warehouse_handover_before_shipment_dispatch();
