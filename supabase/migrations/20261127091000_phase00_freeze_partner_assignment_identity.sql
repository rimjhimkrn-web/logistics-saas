-- Keep partner assignment identity stable. Reassignment must cancel the old
-- partner-specific row and create a new offered row for the replacement partner.
CREATE OR REPLACE FUNCTION private.krim_guard_partner_assignment_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.shipment_id IS DISTINCT FROM OLD.shipment_id
     OR NEW.shipment_leg_id IS DISTINCT FROM OLD.shipment_leg_id
     OR NEW.partner_organization_id IS DISTINCT FROM OLD.partner_organization_id
     OR NEW.partner_quote_id IS DISTINCT FROM OLD.partner_quote_id
     OR NEW.assignment_number IS DISTINCT FROM OLD.assignment_number THEN
    RAISE EXCEPTION USING
      ERRCODE='55000',
      MESSAGE='Partner assignment identity is immutable; cancel the existing assignment and create a new offer for reassignment';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_guard_partner_assignment_identity
ON public.krim_shipment_partner_assignments;

CREATE TRIGGER trg_krim_guard_partner_assignment_identity
BEFORE UPDATE OF shipment_id, shipment_leg_id, partner_organization_id,
                 partner_quote_id, assignment_number
ON public.krim_shipment_partner_assignments
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_partner_assignment_identity();

REVOKE ALL ON FUNCTION private.krim_guard_partner_assignment_identity()
FROM PUBLIC, anon, authenticated, service_role;
