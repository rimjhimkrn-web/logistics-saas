-- Tighten booking data access: readiness is server-maintained, and anonymous roles
-- must not receive direct read grants on partner quote or shipment history tables.
DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='krim_shipment_readiness_gates'
      AND c.relkind='r'
  ) THEN
    RAISE EXCEPTION 'krim_shipment_readiness_gates table not found';
  END IF;
END
$migration$;

DROP POLICY IF EXISTS shipment_org_all
  ON public.krim_shipment_readiness_gates;

CREATE POLICY shipment_org_select
  ON public.krim_shipment_readiness_gates
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.krim_shipments s
      WHERE s.id = krim_shipment_readiness_gates.shipment_id
        AND s.customer_organization_id IS NOT NULL
        AND private.krim_has_organization_access(
          (SELECT auth.uid()),
          s.customer_organization_id
        )
    )
  );

REVOKE INSERT, UPDATE, DELETE
  ON public.krim_shipment_readiness_gates
  FROM authenticated, anon;
GRANT SELECT
  ON public.krim_shipment_readiness_gates
  TO authenticated;

REVOKE ALL
  ON public.krim_partner_quotes, public.krim_shipment_status_history
  FROM anon;
