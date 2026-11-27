-- Phase 00: restore authenticated customer access to guarded route-plan RPCs.
-- The routines validate auth.uid() and shipment.update on the owning customer
-- organization before reading or mutating route-plan state. Keep direct table
-- writes disabled; RLS and existing scoped read policies remain unchanged.

REVOKE ALL ON FUNCTION public.krim_create_shipment_leg_plan(bigint, jsonb, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.krim_evaluate_shipment_leg_plan(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.krim_activate_shipment_leg_plan(bigint, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.krim_create_shipment_leg_plan(bigint, jsonb, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_evaluate_shipment_leg_plan(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.krim_activate_shipment_leg_plan(bigint, text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.krim_create_shipment_leg_plan(bigint, jsonb, text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.krim_evaluate_shipment_leg_plan(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.krim_activate_shipment_leg_plan(bigint, text) TO service_role;
