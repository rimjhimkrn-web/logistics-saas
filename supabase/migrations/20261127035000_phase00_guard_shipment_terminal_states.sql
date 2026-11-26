-- Prevent generic/service-role status writers from bypassing the
-- verified per-leg POD delivery lifecycle.
CREATE OR REPLACE FUNCTION private.krim_guard_shipment_terminal_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status = 'delivered' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.krim_shipment_legs l
      WHERE l.shipment_id = NEW.id
    ) THEN
      RAISE EXCEPTION 'shipment_delivery_requires_at_least_one_leg'
        USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.krim_shipment_legs l
      WHERE l.shipment_id = NEW.id
        AND l.status NOT IN ('completed','delivered')
    ) THEN
      RAISE EXCEPTION 'shipment_delivery_requires_all_legs_completed'
        USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.krim_shipment_legs l
      WHERE l.shipment_id = NEW.id
        AND NOT EXISTS (
          SELECT 1 FROM public.krim_pod_records p
          WHERE p.shipment_id = NEW.id
            AND p.shipment_leg_id = l.id
            AND p.pod_type = 'delivery'
            AND p.status = 'verified'
        )
    ) THEN
      RAISE EXCEPTION 'shipment_delivery_requires_verified_pod_for_every_leg'
        USING ERRCODE = '55000';
    END IF;

    IF NEW.actual_delivery_at IS NULL THEN
      RAISE EXCEPTION 'shipment_delivery_requires_actual_delivery_timestamp'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status = 'closed'
     AND OLD.status NOT IN ('delivered','cancelled') THEN
    RAISE EXCEPTION 'shipment_close_requires_delivered_or_cancelled_state'
      USING ERRCODE = '55000';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_guard_shipment_terminal_state()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_guard_shipment_terminal_state ON public.krim_shipments;
CREATE TRIGGER trg_krim_guard_shipment_terminal_state
BEFORE UPDATE OF status ON public.krim_shipments
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_shipment_terminal_state();
