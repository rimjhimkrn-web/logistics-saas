-- Step 1: enforce server-maintained booking readiness and remove anonymous reads.
REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.krim_shipment_readiness_gates
  FROM authenticated, anon;
GRANT SELECT
  ON TABLE public.krim_shipment_readiness_gates
  TO authenticated;
REVOKE ALL
  ON TABLE public.krim_partner_quotes, public.krim_shipment_status_history
  FROM anon;
