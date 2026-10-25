-- Keep production shipment-leg provisioning reproducible from repository migrations.
-- Creates one initial leg only for supported single-mode bookings. Never fabricates a
-- single leg for multimodal/specialist service requests and never overwrites a route plan.

CREATE OR REPLACE FUNCTION public.krim_ensure_initial_shipment_leg()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_mode_code text;
  v_mode_id bigint;
BEGIN
  IF NEW.requested_transport_mode IS NULL
     OR NEW.origin_location_id IS NULL
     OR NEW.destination_location_id IS NULL
     OR NEW.origin_location_id = NEW.destination_location_id
     OR NEW.status NOT IN ('draft', 'quoted') THEN
    RETURN NEW;
  END IF;

  v_mode_code := CASE lower(btrim(NEW.requested_transport_mode))
    WHEN 'road' THEN 'ROAD'
    WHEN 'rail' THEN 'RAIL'
    WHEN 'ocean' THEN 'OCEAN'
    WHEN 'air' THEN 'AIR'
    WHEN 'warehouse_transfer' THEN 'WAREHOUSE'
    ELSE NULL
  END;

  -- Do not fabricate a single leg for multimodal or specialist services.
  IF v_mode_code IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT tm.id INTO v_mode_id
  FROM public.krim_transport_modes tm
  WHERE tm.code = v_mode_code AND tm.is_active IS TRUE
  ORDER BY tm.id
  LIMIT 1;

  -- Fail closed when the required transport mode is not configured and active.
  IF v_mode_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Preserve existing route plans and never overwrite an existing first leg.
  IF NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_legs sl WHERE sl.shipment_id = NEW.id
  ) THEN
    INSERT INTO public.krim_shipment_legs (
      shipment_id, leg_sequence, origin_location_id, destination_location_id,
      transport_mode_id, status, assignment_status
    )
    VALUES (
      NEW.id, 1, NEW.origin_location_id, NEW.destination_location_id,
      v_mode_id, 'planned', 'unassigned'
    )
    ON CONFLICT (shipment_id, leg_sequence) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_ensure_initial_shipment_leg ON public.krim_shipments;

CREATE TRIGGER trg_krim_ensure_initial_shipment_leg
AFTER INSERT OR UPDATE OF requested_transport_mode, origin_location_id, destination_location_id
ON public.krim_shipments
FOR EACH ROW
EXECUTE FUNCTION public.krim_ensure_initial_shipment_leg();
