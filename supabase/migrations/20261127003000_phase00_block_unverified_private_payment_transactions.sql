-- Prevent direct privileged writes from fabricating a verified/paid payment
-- in the internal transaction mirror while provider verification is disabled.

CREATE OR REPLACE FUNCTION private.krim_block_unverified_private_payment_state()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  IF NEW.status = 'paid' OR NEW.verified_at IS NOT NULL THEN
    RAISE EXCEPTION
      'payment_verification_disabled: internal payment transactions cannot be marked paid or verified until provider webhook verification is implemented'
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_block_unverified_private_payment_state()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_block_unverified_private_payment_state
  ON private.krim_payment_transactions;
CREATE TRIGGER trg_krim_block_unverified_private_payment_state
BEFORE INSERT OR UPDATE OF status, verified_at
ON private.krim_payment_transactions
FOR EACH ROW
EXECUTE FUNCTION private.krim_block_unverified_private_payment_state();
