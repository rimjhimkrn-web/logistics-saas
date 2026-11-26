CREATE OR REPLACE FUNCTION private.krim_guard_partner_assignment_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status IN ('rejected','cancelled','completed','failed') THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='A terminal partner assignment cannot be reopened or changed';
  END IF;

  IF NOT (
    (OLD.status='offered' AND NEW.status IN ('accepted','rejected','cancelled')) OR
    (OLD.status='accepted' AND NEW.status IN ('active','cancelled','failed')) OR
    (OLD.status='active' AND NEW.status IN ('completed','cancelled','failed'))
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Invalid partner assignment status transition';
  END IF;

  IF OLD.status IN ('accepted','active')
     AND NEW.status IN ('cancelled','failed')
     AND EXISTS (
       SELECT 1
       FROM public.krim_driver_assignments da
       JOIN public.krim_driver_trip_events e ON e.assignment_id=da.id
       WHERE da.partner_assignment_id=OLD.id
         AND da.shipment_id=OLD.shipment_id
         AND da.shipment_leg_id=OLD.shipment_leg_id
         AND da.organization_id=OLD.partner_organization_id
         AND e.event_type IN ('pickup','in_transit')
     ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='Partner assignment cannot be cancelled or failed after driver pickup or transit; use the exception and delivery lifecycle';
  END IF;

  RETURN NEW;
END;
$function$;
