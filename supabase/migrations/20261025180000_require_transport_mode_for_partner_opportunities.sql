-- Do not publish partner bid opportunities for shipments without an explicitly selected transport mode.
-- This aligns the opportunity RPC with tariff quote validation and prevents incomplete legacy rows
-- from being broadcast to partners as actionable freight requests.

DO $migration$
DECLARE
  v_definition text;
  v_old text := $$IF v_shipment.status NOT IN ('draft','quoted') THEN RAISE EXCEPTION USING errcode='22023',message='Only draft or quoted shipments can be offered to the partner network'; END IF;

 IF NOT EXISTS ($$;
  v_new text := $$IF v_shipment.status NOT IN ('draft','quoted') THEN RAISE EXCEPTION USING errcode='22023',message='Only draft or quoted shipments can be offered to the partner network'; END IF;

 IF NULLIF(btrim(v_shipment.requested_transport_mode), '') IS NULL THEN
   RAISE EXCEPTION USING errcode='22023', message='Partner bid request blocked: shipment has no recorded transport mode. Confirm the selected mode before requesting partner bids.';
 END IF;

 IF NOT EXISTS ($$;
BEGIN
  SELECT pg_get_functiondef(
    'public.krim_create_partner_opportunity(bigint,timestamp with time zone,text)'::regprocedure
  ) INTO v_definition;

  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected opportunity validation block was not found; refusing to alter function';
  END IF;

  v_definition := replace(v_definition, v_old, v_new);
  EXECUTE v_definition;

  SELECT pg_get_functiondef(
    'public.krim_create_partner_opportunity(bigint,timestamp with time zone,text)'::regprocedure
  ) INTO v_definition;

  IF position('Partner bid request blocked: shipment has no recorded transport mode' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Partner opportunity transport-mode guard verification failed';
  END IF;
END;
$migration$;
