-- Require picked shipment inventory before warehouse dispatch handover can be created or completed.
CREATE OR REPLACE FUNCTION private.krim_guard_dispatch_handover_picked_allocations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.task_type = 'dispatch_handover'
     AND (
       TG_OP = 'INSERT'
       OR (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
     ) THEN
    IF NEW.shipment_id IS NULL OR NEW.shipment_leg_id IS NULL THEN
      RAISE EXCEPTION 'Dispatch handover must be linked to an exact shipment leg'
        USING errcode = '23514';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.krim_warehouse_shipment_allocations a
      WHERE a.organization_id = NEW.organization_id
        AND a.facility_id = NEW.facility_id
        AND a.shipment_id = NEW.shipment_id
        AND a.shipment_leg_id = NEW.shipment_leg_id
        AND a.status = 'picked'
    ) THEN
      RAISE EXCEPTION 'Dispatch handover requires at least one picked inventory allocation for this exact shipment leg and facility'
        USING errcode = '23514';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.krim_warehouse_shipment_allocations a
      WHERE a.organization_id = NEW.organization_id
        AND a.facility_id = NEW.facility_id
        AND a.shipment_id = NEW.shipment_id
        AND a.shipment_leg_id = NEW.shipment_leg_id
        AND a.status = 'reserved'
    ) THEN
      RAISE EXCEPTION 'Dispatch handover is blocked while any inventory allocation for this shipment leg remains reserved and unpicked'
        USING errcode = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_guard_dispatch_handover_picked_allocations() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_krim_dispatch_handover_requires_picked_allocations
ON public.krim_warehouse_tasks;

CREATE TRIGGER trg_krim_dispatch_handover_requires_picked_allocations
BEFORE INSERT OR UPDATE OF status
ON public.krim_warehouse_tasks
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_dispatch_handover_picked_allocations();
