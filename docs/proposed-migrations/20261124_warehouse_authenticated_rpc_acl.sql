-- Proposed staging remediation only. Do not apply to production until migration ledger reconciliation and release approval.
-- Exact browser-invoked warehouse RPCs, confirmed by source call-site inventory on 2026-11-24.
-- Function bodies derive the actor from auth.uid() and enforce warehouse membership/facility/permission scope.
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_list_events(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_create_task(bigint,uuid,text,text,text,text,text,numeric,text,text,text,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_dashboard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_list_tasks(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_transition_task(uuid,text,uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_create_linked_goods_receipt_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_create_linked_inbound_task(bigint,uuid,bigint,bigint,text,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_list_evidence(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.krim_warehouse_register_evidence(uuid,text,text,text,timestamptz) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_events(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_task(bigint,uuid,text,text,text,text,text,numeric,text,text,text,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_tasks(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_transition_task(uuid,text,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_goods_receipt_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_inbound_task(bigint,uuid,bigint,bigint,text,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_list_evidence(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_register_evidence(uuid,text,text,text,timestamptz) TO authenticated;
