-- Internal payment registry and provider transaction tables are backend-only.
-- No browser or authenticated client needs direct table privileges. Edge Functions
-- access these tables through the trusted service_role.
BEGIN;

ALTER TABLE private.krim_payment_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.krim_payment_capabilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.krim_payment_transactions ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE private.krim_payment_providers FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE private.krim_payment_capabilities FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE private.krim_payment_transactions FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.krim_payment_providers TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.krim_payment_capabilities TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.krim_payment_transactions TO service_role;

COMMIT;
