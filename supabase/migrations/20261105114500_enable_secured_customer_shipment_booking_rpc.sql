-- The canonical customer booking page calls this five-argument RPC.
-- Its body enforces active organization membership, shipment.create permission,
-- active locations/countries and operational market gates; expose it only to signed-in users.
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment(
  bigint, bigint, bigint, text, numeric
) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.krim_create_global_shipment(
  bigint, bigint, bigint, text, numeric
) FROM anon;
