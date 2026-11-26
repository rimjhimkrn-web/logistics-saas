-- Phase 00: preserve assignment lifecycle history and prevent orphaned capacity.
CREATE OR REPLACE FUNCTION private.krim_block_partner_assignment_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE='55000',
    MESSAGE='Partner assignments are operational history and cannot be deleted; use an authorised status transition';
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_block_partner_assignment_truncate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE='55000',
    MESSAGE='Partner assignment history cannot be truncated';
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_partner_assignment_no_delete
 ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_partner_assignment_no_delete
 BEFORE DELETE ON public.krim_shipment_partner_assignments
 FOR EACH ROW EXECUTE FUNCTION private.krim_block_partner_assignment_delete();

DROP TRIGGER IF EXISTS trg_krim_partner_assignment_no_truncate
 ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_partner_assignment_no_truncate
 BEFORE TRUNCATE ON public.krim_shipment_partner_assignments
 FOR EACH STATEMENT EXECUTE FUNCTION private.krim_block_partner_assignment_truncate();

REVOKE ALL ON FUNCTION private.krim_block_partner_assignment_delete() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION private.krim_block_partner_assignment_truncate() FROM PUBLIC,anon,authenticated,service_role;

REVOKE DELETE,TRUNCATE ON public.krim_shipment_partner_assignments FROM anon,authenticated,service_role;
