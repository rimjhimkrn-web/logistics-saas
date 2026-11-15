-- Remove duplicate shipment-leg creation audit emission and harden trigger function.
-- Historical duplicate audit rows are retained; no audit history is rewritten.

DROP TRIGGER IF EXISTS trg_krim_shipment_leg_creation_audit
  ON public.krim_shipment_legs;

CREATE OR REPLACE FUNCTION public.krim_log_shipment_leg_creation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.krim_audit_events (
    event_type, entity_type, entity_id, metadata, created_at
  )
  VALUES (
    'shipment_leg_created',
    'shipment_leg',
    NEW.id,
    pg_catalog.jsonb_build_object(
      'shipment_id', NEW.shipment_id,
      'route_segment_id', NEW.route_segment_id
    ),
    pg_catalog.now()
  );
  RETURN NEW;
END;
$function$;
