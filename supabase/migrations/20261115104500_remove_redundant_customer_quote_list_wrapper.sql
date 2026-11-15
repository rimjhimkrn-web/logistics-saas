-- The canonical customer quote-list RPC already accepts a validated
-- array of shipment IDs and enforces access for every requested shipment.
-- Remove the temporary wrapper so the API surface has one canonical route.
DROP FUNCTION IF EXISTS public.krim_customer_list_partner_quotes_multi(bigint[]);
