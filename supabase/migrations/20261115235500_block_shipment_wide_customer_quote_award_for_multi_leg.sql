-- Block customer quote preparation through the legacy shipment-wide award RPC
-- when a multi-leg route plan is active. The guard precedes the idempotent
-- existing-quote return path so retries cannot bypass the restriction.

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_catalog.pg_get_functiondef('public.krim_award_partner_quote_for_checkout(bigint,timestamp with time zone)'::regprocedure) INTO v_def;
  v_old := $old$  SELECT * INTO v_existing_quote
  FROM public.krim_quotes
  WHERE partner_quote_id = p_partner_quote_id
  FOR UPDATE;$old$;
  v_new := $new$  IF EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    WHERE p.shipment_id=v_opportunity.shipment_id AND p.status='active' AND p.total_legs>1
  ) THEN
    RAISE EXCEPTION USING errcode='55000',
      message='This shipment has an active multi-leg plan. Shipment-wide customer quote preparation is disabled until leg-specific sourcing is available';
  END IF;

  SELECT * INTO v_existing_quote
  FROM public.krim_quotes
  WHERE partner_quote_id = p_partner_quote_id
  FOR UPDATE;$new$;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN
    RAISE EXCEPTION 'Could not locate customer quote award idempotency lookup';
  END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);
END
$migration$;
