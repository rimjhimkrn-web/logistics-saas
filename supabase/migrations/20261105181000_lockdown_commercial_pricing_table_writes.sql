-- Step 3: make commercial rate-card records write-only through privileged,
-- permission-checked governance RPCs. Direct authenticated DML is not permitted.
REVOKE ALL ON TABLE public.krim_pricing_rate_cards FROM anon, authenticated;
DROP POLICY IF EXISTS org_isolation_all ON public.krim_pricing_rate_cards;

-- Keep private cost and quote-breakdown records inaccessible to anonymous clients.
REVOKE ALL ON TABLE public.krim_quote_pricing_components FROM anon;
REVOKE ALL ON TABLE public.krim_shipment_cost_items FROM anon;
REVOKE ALL ON TABLE public.krim_rate_cards FROM anon;
REVOKE ALL ON TABLE public.krim_rate_lines FROM anon;
REVOKE ALL ON TABLE public.krim_accessorial_charges FROM anon;

-- Public FX data is not populated or exposed anonymously. Authenticated reads remain
-- governed by the existing authenticated_read policy; write access remains service-only.
REVOKE ALL ON TABLE public.krim_fx_rates FROM anon, authenticated;
GRANT SELECT ON TABLE public.krim_fx_rates TO authenticated;

-- Keep RLS enabled as defence in depth even though the global rate-card table is
-- accessed only through admin-gated SECURITY DEFINER functions and internal quote logic.
ALTER TABLE public.krim_pricing_rate_cards ENABLE ROW LEVEL SECURITY;
