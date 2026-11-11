-- Prevent customer quote acceptance unless the linked partner offer is valid
-- and its shipment assignment has been explicitly accepted.
-- Apply only after production migration-history reconciliation and staging verification.

CREATE OR REPLACE FUNCTION public.krim_accept_global_quote(p_quote_id bigint)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_quote public.krim_quotes%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_partner_quote public.krim_partner_quotes%ROWTYPE;
BEGIN
  SELECT *
  INTO v_quote
  FROM public.krim_quotes
  WHERE id = p_quote_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Global quote not found';
  END IF;

  SELECT *
  INTO v_shipment
  FROM public.krim_shipments
  WHERE id = v_quote.shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;

  IF v_quote.customer_organization_id IS NULL
     OR v_shipment.customer_organization_id IS DISTINCT FROM v_quote.customer_organization_id THEN
    RAISE EXCEPTION 'Quote and shipment customer organization do not match';
  END IF;

  IF NOT public.krim_has_organization_access(auth.uid(), v_quote.customer_organization_id) THEN
    RAISE EXCEPTION 'Organization access denied';
  END IF;

  IF NOT public.krim_has_permission(auth.uid(), v_quote.customer_organization_id, 'shipment.update') THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF v_quote.status <> 'sent' THEN
    RAISE EXCEPTION 'Quote cannot be accepted from status: %', v_quote.status;
  END IF;

  IF v_quote.valid_until IS NULL OR v_quote.valid_until <= now() THEN
    UPDATE public.krim_quotes
    SET status = 'expired', updated_at = now()
    WHERE id = v_quote.id;
    v_quote.status := 'expired';
    v_quote.updated_at := now();
    RETURN v_quote;
  END IF;

  IF v_shipment.status <> 'quoted' THEN
    RAISE EXCEPTION 'Shipment must be in quoted status. Current status: %', v_shipment.status;
  END IF;

  IF v_quote.partner_quote_id IS NULL THEN
    RAISE EXCEPTION 'A linked partner offer is required before customer acceptance';
  END IF;

  SELECT *
  INTO v_partner_quote
  FROM public.krim_partner_quotes
  WHERE id = v_quote.partner_quote_id
    AND shipment_id = v_shipment.id
    AND status IN ('submitted', 'under_review', 'shortlisted', 'accepted')
    AND valid_until > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Linked partner offer is missing, expired or not eligible';
  END IF;

  IF v_partner_quote.amount IS DISTINCT FROM v_quote.amount
     OR upper(v_partner_quote.currency_code) IS DISTINCT FROM upper(v_quote.currency_code) THEN
    RAISE EXCEPTION 'Customer quote amount or currency does not match the linked partner offer';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.krim_shipment_partner_assignments a
    WHERE a.shipment_id = v_shipment.id
      AND a.partner_quote_id = v_partner_quote.id
      AND a.partner_organization_id = v_partner_quote.partner_organization_id
      AND a.status = 'accepted'
  ) THEN
    RAISE EXCEPTION 'The linked partner assignment must be accepted before customer acceptance';
  END IF;

  UPDATE public.krim_quotes
  SET status = 'accepted', updated_at = now()
  WHERE id = v_quote.id
  RETURNING * INTO v_quote;

  PERFORM public.krim_transition_shipment(
    v_shipment.id,
    'confirmed',
    'Global quote accepted by customer',
    jsonb_build_object(
      'quote_id', v_quote.id,
      'partner_quote_id', v_partner_quote.id,
      'amount', v_quote.amount,
      'currency_code', v_quote.currency_code
    )
  );

  RETURN v_quote;
END;
$function$;
