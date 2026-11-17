-- Restore authenticated execution for the guarded partner dispatch and driver workflows.
-- Each RPC independently enforces auth.uid(), partner permissions or driver ownership,
-- exact shipment/leg linkage, verification, compliance and operational readiness.
REVOKE ALL ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_assign_driver_to_partner_shipment(bigint,uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_list_dispatchable_drivers(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_list_dispatchable_drivers(bigint) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_driver_accept_assignment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_accept_assignment(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_authorize_leg_dispatch(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_authorize_leg_dispatch(bigint,text) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_revoke_leg_dispatch_authorization(bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_revoke_leg_dispatch_authorization(bigint,text) TO authenticated;
