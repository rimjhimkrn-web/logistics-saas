-- Restore authenticated partner access to the two guarded assignment actions.
-- Both SECURITY DEFINER RPCs validate auth.uid(), active organization membership,
-- partner permissions, assignment ownership, eligibility and exact shipment bindings.
REVOKE ALL ON FUNCTION public.krim_respond_to_partner_assignment(bigint,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_respond_to_partner_assignment(bigint,boolean,text) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text) TO authenticated;
