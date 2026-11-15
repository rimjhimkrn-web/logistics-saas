-- Fail closed on shipment-wide partner sourcing after a multi-leg plan is active.
-- The current opportunity/quote model has no leg identifier. Allowing it to proceed
-- would award a whole-shipment quote to only the first leg, so block until the
-- dedicated leg-specific sourcing workflow is released.

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_catalog.pg_get_functiondef('public.krim_create_partner_opportunity(bigint,timestamp with time zone,text)'::regprocedure) INTO v_def;
  v_old := $old$ IF v_shipment.status NOT IN ('draft','quoted') THEN RAISE EXCEPTION USING errcode='22023',message='Only draft or quoted shipments can be offered to the partner network'; END IF;$old$;
  v_new := v_old || $new$
  IF EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    WHERE p.shipment_id=v_shipment.id AND p.status='active' AND p.total_legs>1
  ) THEN
    RAISE EXCEPTION USING errcode='55000',
      message='This shipment has an active multi-leg plan. Shipment-wide partner sourcing is disabled until leg-specific sourcing is available.';
  END IF;
$new$;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'Could not locate shipment opportunity status guard'; END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);

  SELECT pg_catalog.pg_get_functiondef('public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)'::regprocedure) INTO v_def;
  v_old := $old$  IF NOT private.krim_partner_capability_covers_shipment(v_partner_organization_id,v_opportunity.shipment_id) THEN$old$;
  v_new := $new$  IF EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    WHERE p.shipment_id=v_opportunity.shipment_id AND p.status='active' AND p.total_legs>1
  ) THEN
    RAISE EXCEPTION USING errcode='55000',
      message='This shipment has an active multi-leg plan. Shipment-wide partner quotes are disabled until leg-specific sourcing is available';
  END IF;

  IF NOT private.krim_partner_capability_covers_shipment(v_partner_organization_id,v_opportunity.shipment_id) THEN$new$;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'Could not locate partner quote capability guard'; END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);

  SELECT pg_catalog.pg_get_functiondef('public.krim_award_partner_quote(bigint)'::regprocedure) INTO v_def;
  v_old := $old$  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN$old$;
  v_new := $new$  IF EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    WHERE p.shipment_id=v_shipment.id AND p.status='active' AND p.total_legs>1
  ) THEN
    RAISE EXCEPTION USING errcode='55000',
      message='This shipment has an active multi-leg plan. Shipment-wide partner awards are disabled until leg-specific sourcing is available';
  END IF;

  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN$new$;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'Could not locate partner award capability guard'; END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);
END
$migration$;
