-- Phase 00: harden the existing partner assignment audit trigger function.
-- Preserve full before/after evidence while removing public from SECURITY DEFINER search_path.

CREATE OR REPLACE FUNCTION public.krim_audit_partner_assignment_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  INSERT INTO public.krim_audit_events
    (actor_user_id, organization_id, event_type, entity_type, entity_id,
     source, metadata, previous_state, new_state)
  VALUES
    (coalesce(auth.uid(), NEW.assigned_by),
     NEW.partner_organization_id,
     CASE
       WHEN TG_OP = 'INSERT' THEN 'partner_assignment_created'
       WHEN OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted' THEN 'partner_assignment_accepted'
       WHEN OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'rejected' THEN 'partner_assignment_rejected'
       WHEN OLD.status IS DISTINCT FROM NEW.status THEN 'partner_assignment_status_changed'
       ELSE 'partner_assignment_updated'
     END,
     'shipment_partner_assignment',
     NEW.id::text,
     'partner_portal',
     jsonb_build_object(
       'shipment_id', NEW.shipment_id,
       'shipment_leg_id', NEW.shipment_leg_id,
       'partner_quote_id', NEW.partner_quote_id,
       'assignment_number', NEW.assignment_number,
       'status', NEW.status
     ),
     CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END,
     to_jsonb(NEW));
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_audit_partner_assignment_changes()
FROM PUBLIC, anon, authenticated, service_role;
