-- Do not infer a transport mode from the commercial service tier.
-- The mode selected in the booking request is authoritative; legacy records without it
-- must be repaired from booking evidence before they can receive a tariff quote.

DO $migration$
DECLARE
  v_definition text;
  v_old text := $$v_mode_code:=CASE coalesce(v_shipment.requested_transport_mode,'') WHEN 'road' THEN 'ROAD' WHEN 'rail' THEN 'RAIL' WHEN 'ocean' THEN 'OCEAN' WHEN 'air' THEN 'AIR' WHEN 'multimodal' THEN 'MULTIMODAL' WHEN 'warehouse_transfer' THEN 'WAREHOUSE' WHEN 'specialist' THEN 'SPECIALIST' ELSE CASE p_service_tier WHEN 'surface_express' THEN 'ROAD' WHEN 'air_priority' THEN 'AIR' WHEN 'heavy_haul' THEN 'ROAD' END END;$$;
  v_new text := $$IF NULLIF(btrim(v_shipment.requested_transport_mode), '') IS NULL THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Tariff quote blocked: shipment has no recorded transport mode. Update the shipment with its selected transport mode before requesting pricing.';
  END IF;

  v_mode_code:=CASE v_shipment.requested_transport_mode
    WHEN 'road' THEN 'ROAD'
    WHEN 'rail' THEN 'RAIL'
    WHEN 'ocean' THEN 'OCEAN'
    WHEN 'air' THEN 'AIR'
    WHEN 'multimodal' THEN 'MULTIMODAL'
    WHEN 'warehouse_transfer' THEN 'WAREHOUSE'
    WHEN 'specialist' THEN 'SPECIALIST'
    ELSE NULL
  END;$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.krim_create_tariff_quote(bigint,text,timestamp with time zone)'::regprocedure
  ) INTO v_definition;

  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected transport-mode fallback was not found; refusing to alter tariff quote function';
  END IF;

  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;

  SELECT pg_get_functiondef(
    'public.krim_create_tariff_quote(bigint,text,timestamp with time zone)'::regprocedure
  ) INTO v_definition;

  IF position('shipment has no recorded transport mode' IN v_definition) = 0
     OR position('ELSE CASE p_service_tier' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'Tariff quote mode guard verification failed';
  END IF;
END;
$migration$;
