-- Retire the legacy location-ID shipment RPC: it can create a shipment without
-- recording the required transport mode. The current booking flow uses the
-- idempotent global booking RPC with explicit transport mode and route type.
REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment(bigint, bigint, bigint, text, numeric)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment(bigint, bigint, bigint, text, numeric)
TO service_role;

-- Trigger functions are invoked by their registered trigger, not exposed as RPCs.
-- Remove inherited client execution privileges while preserving the trigger.
REVOKE EXECUTE ON FUNCTION public.krim_ensure_initial_shipment_leg()
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_ensure_initial_shipment_leg()
TO service_role;
