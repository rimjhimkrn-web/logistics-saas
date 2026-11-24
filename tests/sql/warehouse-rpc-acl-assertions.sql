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
