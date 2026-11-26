-- Legacy service-role transit/arrival routines bypass the current
-- exact-leg driver/POD lifecycle. Their discovered database and repository
-- call-site searches returned no callers. Disable pending an explicit,
-- verified replacement; the authenticated driver trip-event and POD
-- authorization workflows remain the supported lifecycle.
REVOKE ALL ON FUNCTION public.krim_internal_start_shipment_transit(bigint) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.krim_internal_arrive_shipment(bigint) FROM PUBLIC,anon,authenticated,service_role;

COMMENT ON FUNCTION public.krim_internal_start_shipment_transit(bigint) IS
'DISABLED in Phase 00 Staging: legacy service-role lifecycle bypass. Use authorized driver trip-event workflow.';
COMMENT ON FUNCTION public.krim_internal_arrive_shipment(bigint) IS
'DISABLED in Phase 00 Staging: legacy routine writes unsupported leg status arrived and bypasses verified POD delivery authorization.';
