-- Phase 00: fail-closed invoice lifecycle and immutability protections.
-- Staging only. Invoice creation/payment workflows remain disabled until the
-- KRIM-owned commercial billing service is implemented and verified.

CREATE OR REPLACE FUNCTION private.krim_guard_invoice_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='commercial_invoice_creation_disabled: KRIM commercial billing workflow is not yet implemented';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='invoice_deletion_blocked: invoices must be preserved; use a verified void or credit-note workflow';
  END IF;
  IF OLD.invoice_number IS DISTINCT FROM NEW.invoice_number OR OLD.organization_id IS DISTINCT FROM NEW.organization_id THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='invoice_identity_immutable: invoice number and issuing organisation cannot be changed';
  END IF;
  IF OLD.status <> 'draft' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='issued_invoice_immutable: changes require a verified payment, void, refund or credit-note workflow';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_guard_invoice_item_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE v_invoice_status text; v_invoice_id bigint;
BEGIN
  v_invoice_id := CASE WHEN TG_OP='DELETE' THEN OLD.invoice_id ELSE NEW.invoice_id END;
  IF TG_OP='UPDATE' AND OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='invoice_item_parent_immutable: invoice items cannot be moved between invoices';
  END IF;
  SELECT i.status INTO v_invoice_status FROM public.krim_invoices i WHERE i.id=v_invoice_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='invoice_item_parent_missing: invoice does not exist';
  END IF;
  IF v_invoice_status <> 'draft' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='issued_invoice_items_immutable: invoice items cannot be changed after issue';
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_block_invoice_truncate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
  RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='invoice_truncate_blocked: invoice records must be preserved';
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_invoice_lifecycle ON public.krim_invoices;
CREATE TRIGGER trg_krim_invoice_lifecycle BEFORE INSERT OR UPDATE OR DELETE ON public.krim_invoices
FOR EACH ROW EXECUTE FUNCTION private.krim_guard_invoice_lifecycle();
DROP TRIGGER IF EXISTS trg_krim_invoice_no_truncate ON public.krim_invoices;
CREATE TRIGGER trg_krim_invoice_no_truncate BEFORE TRUNCATE ON public.krim_invoices
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_invoice_truncate();
DROP TRIGGER IF EXISTS trg_krim_invoice_item_lifecycle ON public.krim_invoice_items;
CREATE TRIGGER trg_krim_invoice_item_lifecycle BEFORE INSERT OR UPDATE OR DELETE ON public.krim_invoice_items
FOR EACH ROW EXECUTE FUNCTION private.krim_guard_invoice_item_lifecycle();
DROP TRIGGER IF EXISTS trg_krim_invoice_item_no_truncate ON public.krim_invoice_items;
CREATE TRIGGER trg_krim_invoice_item_no_truncate BEFORE TRUNCATE ON public.krim_invoice_items
FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_invoice_truncate();

REVOKE ALL ON FUNCTION private.krim_guard_invoice_lifecycle() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.krim_guard_invoice_item_lifecycle() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.krim_block_invoice_truncate() FROM PUBLIC, anon, authenticated, service_role;
REVOKE UPDATE, DELETE, TRUNCATE ON public.krim_invoices FROM service_role;
REVOKE UPDATE, DELETE, TRUNCATE ON public.krim_invoice_items FROM service_role;
