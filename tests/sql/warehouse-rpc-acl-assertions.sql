DO $$
DECLARE r record;
BEGIN
 FOR r IN
  SELECT p.oid,p.proname,pg_get_function_identity_arguments(p.oid) args
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN (
   'krim_warehouse_list_events','krim_warehouse_create_task','krim_warehouse_dashboard',
   'krim_warehouse_review_inventory_quality','krim_warehouse_create_linked_pick_task',
   'krim_warehouse_list_tasks','krim_warehouse_transition_task',
   'krim_warehouse_list_assigned_shipment_legs','krim_warehouse_create_linked_goods_receipt_task',
   'krim_warehouse_create_linked_inbound_task','krim_warehouse_create_linked_handover_task',
   'krim_warehouse_register_facility','krim_warehouse_list_evidence','krim_warehouse_register_evidence'
  )
 LOOP
  IF has_function_privilege('anon',r.oid,'EXECUTE') THEN
   RAISE EXCEPTION 'anon unexpectedly has EXECUTE on %(%)',r.proname,r.args;
  END IF;
  IF NOT has_function_privilege('authenticated',r.oid,'EXECUTE') THEN
   RAISE EXCEPTION 'authenticated lacks required EXECUTE on %(%)',r.proname,r.args;
  END IF;
  IF NOT has_function_privilege('service_role',r.oid,'EXECUTE') THEN
   RAISE EXCEPTION 'service_role lost EXECUTE on %(%)',r.proname,r.args;
  END IF;
 END LOOP;
 IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proname IN (
      'krim_warehouse_list_events','krim_warehouse_create_task','krim_warehouse_dashboard',
      'krim_warehouse_review_inventory_quality','krim_warehouse_create_linked_pick_task',
      'krim_warehouse_list_tasks','krim_warehouse_transition_task',
      'krim_warehouse_list_assigned_shipment_legs','krim_warehouse_create_linked_goods_receipt_task',
      'krim_warehouse_create_linked_inbound_task','krim_warehouse_create_linked_handover_task',
      'krim_warehouse_register_facility','krim_warehouse_list_evidence','krim_warehouse_register_evidence'
     )) <> 14 THEN RAISE EXCEPTION 'Expected 14 exact warehouse RPC overloads in fixture'; END IF;
END $$;

DO $$
DECLARE t text; rel oid;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'krim_warehouse_facilities','krim_warehouse_inventory',
  'krim_warehouse_tasks','krim_warehouse_shipment_allocations'
 ] LOOP
  SELECT c.oid INTO rel FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname=t;
  IF rel IS NULL THEN RAISE EXCEPTION 'Missing warehouse table public.%',t; END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=rel) THEN
   RAISE EXCEPTION 'RLS disabled on public.%',t;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND cmd IN ('SELECT','ALL')) THEN
   RAISE EXCEPTION 'Missing SELECT policy on public.%',t;
  END IF;
  IF NOT has_table_privilege('authenticated',rel,'SELECT') THEN RAISE EXCEPTION 'authenticated lacks SELECT on public.%',t; END IF;
  IF has_table_privilege('anon',rel,'SELECT') THEN RAISE EXCEPTION 'anon has SELECT on public.%',t; END IF;
  IF has_table_privilege('authenticated',rel,'INSERT') OR
     has_table_privilege('authenticated',rel,'UPDATE') OR
     has_table_privilege('authenticated',rel,'DELETE') OR
     has_table_privilege('authenticated',rel,'TRUNCATE') THEN
   RAISE EXCEPTION 'authenticated has direct DML on public.%',t;
  END IF;
  IF NOT has_table_privilege('service_role',rel,'SELECT') OR
     NOT has_table_privilege('service_role',rel,'INSERT') THEN
   RAISE EXCEPTION 'service_role privileges were not preserved on public.%',t;
  END IF;
 END LOOP;
END $$;

-- Verify RLS filters the fixture rows after the role receives SELECT.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('krim.test_org_id','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
DO $$
DECLARE n bigint;
BEGIN
 SELECT count(*) INTO n FROM public.krim_warehouse_facilities;
 IF n<>1 THEN RAISE EXCEPTION 'facility RLS expected one tenant row, got %',n; END IF;
 SELECT count(*) INTO n FROM public.krim_warehouse_inventory;
 IF n<>1 THEN RAISE EXCEPTION 'inventory RLS expected one tenant row, got %',n; END IF;
 SELECT count(*) INTO n FROM public.krim_warehouse_tasks;
 IF n<>1 THEN RAISE EXCEPTION 'task RLS expected one tenant row, got %',n; END IF;
 SELECT count(*) INTO n FROM public.krim_warehouse_shipment_allocations;
 IF n<>1 THEN RAISE EXCEPTION 'allocation RLS expected one tenant row, got %',n; END IF;
END $$;
ROLLBACK;
