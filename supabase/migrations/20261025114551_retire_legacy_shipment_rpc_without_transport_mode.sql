-- The current customer booking flow uses the idempotent RPC that requires transport mode and route type.
-- Retire only the obsolete 5-argument overload, which permits authenticated callers to create
-- shipments without recording a transport mode. Keep service_role access for controlled maintenance.
REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment_from_places(bigint, jsonb, jsonb, text, numeric)
FROM PUBLIC, anon, authenticated;
