-- Batch customer quote enrichment through the existing per-shipment
-- authorization function. The wrapper is SECURITY INVOKER and preserves
-- each shipment-level ownership check.
CREATE OR REPLACE FUNCTION public.krim_customer_list_partner_quotes_multi(
  p_shipment_ids bigint[]
)
RETURNS TABLE (
  id bigint,
  opportunity_id bigint,
  shipment_id bigint,
  quote_number text,
  amount numeric,
  currency_code text,
  status text,
  submitted_at timestamptz,
  valid_until timestamptz,
  notes text,
  partner_name text,
  partner_legal_name text,
  partner_verified boolean,
  compliance_current boolean,
  capability_current boolean,
  eligible_now boolean
)
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_shipment_id bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;

  IF p_shipment_ids IS NULL
     OR cardinality(p_shipment_ids) < 1
     OR cardinality(p_shipment_ids) > 100
     OR EXISTS (
       SELECT 1 FROM unnest(p_shipment_ids) AS x
       WHERE x IS NULL OR x <= 0
     ) THEN
    RAISE EXCEPTION USING errcode='22023',
      message='Provide between 1 and 100 valid shipment IDs';
  END IF;

  FOR v_shipment_id IN
    SELECT DISTINCT x
    FROM unnest(p_shipment_ids) AS x
    ORDER BY x
  LOOP
    RETURN QUERY
      SELECT *
      FROM public.krim_customer_list_partner_quotes(v_shipment_id);
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_customer_list_partner_quotes_multi(bigint[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_customer_list_partner_quotes_multi(bigint[])
  TO authenticated;
