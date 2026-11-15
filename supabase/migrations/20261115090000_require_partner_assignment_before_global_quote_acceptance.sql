CREATE OR REPLACE FUNCTION public.krim_accept_global_quote(p_quote_id bigint)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_quote public.krim_quotes%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_quote FROM public.krim_quotes WHERE id = p_quote_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002', message='Global quote not found'; END IF;
  SELECT * INTO v_shipment FROM public.krim_shipments WHERE id = v_quote.shipment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0002', message='Shipment not found'; END IF;
  IF v_quote.customer_organization_id IS NULL THEN RAISE EXCEPTION USING errcode='23514', message='Quote has no customer organization'; END IF;
  IF NOT public.krim_has_organization_access(auth.uid(), v_quote.customer_organization_id) THEN RAISE EXCEPTION USING errcode='42501', message='Organization access denied'; END IF;
  IF NOT public.krim_has_permission(auth.uid(), v_quote.customer_organization_id, 'shipment.update') THEN RAISE EXCEPTION USING errcode='42501', message='Permission denied'; END IF;
  IF v_quote.status <> 'sent' THEN
    RAISE EXCEPTION USING errcode='55000', message=format('Quote cannot be accepted from status: %s', v_quote.status);
  END IF;
  IF v_quote.valid_until IS NOT NULL AND v_quote.valid_until <= now() THEN
    UPDATE public.krim_quotes SET status='expired', updated_at=now() WHERE id=v_quote.id RETURNING * INTO v_quote;
    RETURN v_quote;
  END IF;
  IF v_shipment.status <> 'quoted' THEN
    RAISE EXCEPTION USING errcode='55000', message=format('Shipment must be in quoted status. Current status: %s', v_shipment.status);
  END IF;
  IF v_quote.partner_quote_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.krim_partner_quotes pq
    JOIN public.krim_shipment_partner_assignments a
      ON a.partner_quote_id=pq.id AND a.shipment_id=pq.shipment_id
     AND a.partner_organization_id=pq.partner_organization_id
    JOIN public.krim_organizations o
      ON o.id=a.partner_organization_id AND o.status='active'
     AND o.partner_verification_status IN ('verified','approved')
     AND o.partner_lifecycle_status IN ('active','verified')
     AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    WHERE pq.id=v_quote.partner_quote_id
      AND pq.shipment_id=v_shipment.id
      AND pq.status='accepted'
      AND a.status='accepted'
      AND pq.amount=v_quote.amount
      AND upper(pq.currency_code)=upper(v_quote.currency_code)
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=o.id AND pc.active IS TRUE
          AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
      )
      AND private.krim_partner_capability_covers_shipment(o.id,v_shipment.id)
  ) THEN
    RAISE EXCEPTION USING errcode='23514',
      message='A customer quote can be accepted only after a verified partner quote and matching partner assignment have been accepted for this shipment';
  END IF;
  UPDATE public.krim_quotes SET status='accepted', updated_at=now()
  WHERE id=v_quote.id RETURNING * INTO v_quote;
  PERFORM public.krim_transition_shipment(
    v_shipment.id,'confirmed','Global quote accepted after partner assignment acceptance',
    jsonb_build_object('quote_id',v_quote.id,'partner_quote_id',v_quote.partner_quote_id,'amount',v_quote.amount,'currency_code',v_quote.currency_code)
  );
  RETURN v_quote;
END;
$function$;
