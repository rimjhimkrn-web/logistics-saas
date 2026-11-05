-- Trigger-only synchronization function must not be callable as an RPC.
-- PostgreSQL invokes trigger functions through their attached triggers; client roles
-- do not need EXECUTE privileges on the trigger function itself.
REVOKE ALL ON FUNCTION public.sync_shipment_status_from_dispatch() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_shipment_status_from_dispatch() FROM anon;
REVOKE ALL ON FUNCTION public.sync_shipment_status_from_dispatch() FROM authenticated;
