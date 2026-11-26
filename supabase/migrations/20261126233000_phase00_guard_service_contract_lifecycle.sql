-- Phase 00: fail-closed service contract lifecycle.
-- No contract authoring/acceptance workflow exists; prevent unverified agreements
-- from authorising billing, partner freight charges or settlement.

CREATE OR REPLACE FUNCTION private.krim_guard_service_contract_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='service_contract_creation_disabled: verified contract authoring and bilateral acceptance are not implemented';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='service_contract_deletion_blocked: preserve agreement history; use a verified termination workflow';
  END IF;
  IF OLD.contract_number IS DISTINCT FROM NEW.contract_number
     OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
     OR OLD.counterparty_organization_id IS DISTINCT FROM NEW.counterparty_organization_id
     OR OLD.contract_type IS DISTINCT FROM NEW.contract_type THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='service_contract_parties_immutable: contract identity and parties cannot be reassigned';
  END IF;
  IF OLD.status <> 'draft' THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='service_contract_immutable: accepted or active agreements require a verified amendment or termination workflow';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_block_service_contract_truncate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  RAISE EXCEPTION USING ERRCODE='55000',
    MESSAGE='service_contract_truncate_blocked: preserve contract and audit history';
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_service_contract_lifecycle ON public.krim_service_contracts;
CREATE TRIGGER trg_krim_service_contract_lifecycle
BEFORE INSERT OR UPDATE OR DELETE ON public.krim_service_contracts
FOR EACH ROW EXECUTE FUNCTION private.krim_guard_service_contract_lifecycle();

DROP TRIGGER IF EXISTS trg_krim_service_contract_no_truncate ON public.krim_service_contracts;
CREATE TRIGGER trg_krim_service_contract_no_truncate
BEFORE TRUNCATE ON public.krim_service_contracts
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_service_contract_truncate();

REVOKE ALL ON FUNCTION private.krim_guard_service_contract_lifecycle() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.krim_block_service_contract_truncate() FROM PUBLIC, anon, authenticated, service_role;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.krim_service_contracts FROM anon, authenticated, service_role;