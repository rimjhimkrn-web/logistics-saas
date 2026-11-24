-- Proposed staging remediation only. This grants read access only to warehouse tables
-- directly queried by current browser pages. Existing RLS policies remain the row boundary.
-- Do not apply to production until migration-ledger reconciliation and release approval.
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'krim_warehouse_facilities',
  'krim_warehouse_inventory',
  'krim_warehouse_tasks',
  'krim_warehouse_shipment_allocations'
 ] LOOP
  IF NOT EXISTS (
   SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname=t AND c.relkind='r' AND c.relrowsecurity
  ) THEN
   RAISE EXCEPTION 'Refusing browser SELECT grant: public.% is missing or RLS is disabled',t;
  END IF;
  IF NOT EXISTS (
   SELECT 1 FROM pg_policies p
   WHERE p.schemaname='public' AND p.tablename=t AND p.cmd IN ('SELECT','ALL')
  ) THEN
   RAISE EXCEPTION 'Refusing browser SELECT grant: public.% has no SELECT policy',t;
  END IF;
 END LOOP;
END $$;

REVOKE ALL ON TABLE public.krim_warehouse_facilities FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.krim_warehouse_facilities FROM authenticated;
GRANT SELECT ON TABLE public.krim_warehouse_facilities TO authenticated;

REVOKE ALL ON TABLE public.krim_warehouse_inventory FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.krim_warehouse_inventory FROM authenticated;
GRANT SELECT ON TABLE public.krim_warehouse_inventory TO authenticated;

REVOKE ALL ON TABLE public.krim_warehouse_tasks FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.krim_warehouse_tasks FROM authenticated;
GRANT SELECT ON TABLE public.krim_warehouse_tasks TO authenticated;

REVOKE ALL ON TABLE public.krim_warehouse_shipment_allocations FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.krim_warehouse_shipment_allocations FROM authenticated;
GRANT SELECT ON TABLE public.krim_warehouse_shipment_allocations TO authenticated;
