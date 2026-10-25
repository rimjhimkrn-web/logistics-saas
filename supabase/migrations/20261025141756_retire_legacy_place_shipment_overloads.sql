-- Retire client-callable place-based shipment overloads that omit the route type.
-- The supported browser flow uses krim_create_global_shipment_idempotent(..., p_transport_mode, p_route_type, p_booking_request_id).
REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment_from_places(bigint, jsonb, jsonb, text, numeric)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment_from_places(bigint, jsonb, jsonb, text, numeric)
TO service_role;

REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment_from_places(bigint, jsonb, jsonb, text, numeric, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment_from_places(bigint, jsonb, jsonb, text, numeric, text)
TO service_role;
