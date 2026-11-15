-- RLS policies invoke this SECURITY DEFINER boolean helper directly.
-- Grant only authenticated execution; anonymous access remains denied.
GRANT EXECUTE
ON FUNCTION private.krim_partner_capability_covers_shipment(bigint,bigint)
TO authenticated;
