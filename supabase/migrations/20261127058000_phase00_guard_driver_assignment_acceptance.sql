-- Driver assignment acceptance must be performed by the assigned driver
-- against the same still-live partner assignment. Preserve acceptance metadata
-- and prevent terminal assignments from being reopened.

CREATE OR REPLACE FUNCTION private.krim_guard_driver_assignment_acceptance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    IF OLD.status = 'accepted'
       AND (NEW.accepted_by IS DISTINCT FROM OLD.accepted_by
         OR NEW.accepted_at IS DISTINCT FROM OLD.accepted_at) THEN
      RAISE EXCEPTION USING ERRCODE='55000',
        MESSAGE='Driver assignment acceptance identity and timestamp are immutable';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status IN ('cancelled','delivered') THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='A terminal driver assignment cannot be reopened';
  END IF;

  IF NEW.status = 'accepted' THEN
    IF OLD.status <> 'assigned'
       OR NEW.accepted_by IS DISTINCT FROM OLD.user_id
       OR NEW.accepted_at IS NULL THEN
      RAISE EXCEPTION USING ERRCODE='42501',
        MESSAGE='Only the assigned driver can accept a pending assignment with recorded acceptance identity';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.krim_organization_members m
      WHERE m.user_id = OLD.user_id
        AND m.organization_id = OLD.organization_id
        AND lower(m.role) = 'driver'
        AND lower(m.status) = 'active'
    ) THEN
      RAISE EXCEPTION USING ERRCODE='42501',
        MESSAGE='An active driver membership is required to accept this assignment';
    END IF;

    IF OLD.partner_assignment_id IS NULL
       OR OLD.shipment_id IS NULL
       OR OLD.shipment_leg_id IS NULL
       OR NOT EXISTS (
         SELECT 1
         FROM public.krim_shipment_partner_assignments pa
         WHERE pa.id = OLD.partner_assignment_id
           AND pa.shipment_id = OLD.shipment_id
           AND pa.shipment_leg_id = OLD.shipment_leg_id
           AND pa.partner_organization_id = OLD.organization_id
           AND pa.status IN ('accepted','active')
       ) THEN
      RAISE EXCEPTION USING ERRCODE='55000',
        MESSAGE='Driver acceptance requires the exact linked partner assignment to remain accepted or active';
    END IF;
  END IF;

  IF OLD.status = 'accepted'
     AND (NEW.accepted_by IS DISTINCT FROM OLD.accepted_by
       OR NEW.accepted_at IS DISTINCT FROM OLD.accepted_at) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Driver assignment acceptance identity and timestamp are immutable';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_guard_driver_assignment_acceptance
ON public.krim_driver_assignments;

CREATE TRIGGER trg_krim_guard_driver_assignment_acceptance
BEFORE UPDATE OF status, accepted_by, accepted_at
ON public.krim_driver_assignments
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_driver_assignment_acceptance();

REVOKE ALL ON FUNCTION private.krim_guard_driver_assignment_acceptance()
FROM PUBLIC, anon, authenticated, service_role;
