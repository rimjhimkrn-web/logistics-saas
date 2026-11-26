-- Phase 00: deliver customer shipment lifecycle events to the in-app inbox.
-- Email/push remain disabled until recipient verification and provider setup.

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS source_event_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_source_event_user
  ON public.notifications (source_event_id, user_id)
  WHERE source_event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.krim_internal_emit_shipment_created_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  INSERT INTO public.krim_events (
    event_id, organization_id, entity_type, entity_id, event_type,
    event_version, source, actor_user_id, occurred_at, payload, metadata,
    processing_status, processing_attempts, created_at
  )
  VALUES (
    gen_random_uuid(), NEW.customer_organization_id, 'shipment', NEW.id,
    'shipment.created', 1, 'shipment.created', auth.uid(), clock_timestamp(),
    jsonb_build_object(
      'shipment_id', NEW.id,
      'shipment_number', NEW.shipment_number,
      'status', NEW.status,
      'created_at', NEW.created_at
    ),
    jsonb_build_object('trigger', 'krim_shipment_created_in_app_event'),
    'pending', 0, clock_timestamp()
  );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_create_customer_shipment_in_app_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_shipment_id bigint;
  v_customer_org_id bigint;
  v_title text;
  v_message text;
  v_status text;
BEGIN
  IF NEW.event_type NOT IN ('shipment.created', 'shipment.status_changed')
     OR NEW.entity_type <> 'shipment' THEN
    RETURN NEW;
  END IF;

  v_shipment_id := COALESCE((NEW.payload->>'shipment_id')::bigint, NEW.entity_id);
  SELECT s.customer_organization_id
    INTO v_customer_org_id
  FROM public.krim_shipments s
  WHERE s.id = v_shipment_id
    AND s.customer_organization_id = NEW.organization_id;

  IF v_customer_org_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.krim_organizations o
    WHERE o.id = v_customer_org_id
      AND o.organization_type IN ('customer', 'enterprise')
      AND o.status = 'active'
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.event_type = 'shipment.created' THEN
    v_title := 'Booking received';
    v_message := 'Your shipment booking ' ||
      COALESCE((NEW.payload->>'shipment_number'), 'request') ||
      ' has been created. You can follow its progress in your KRIM workspace.';
  ELSE
    v_status := lower(COALESCE(NEW.payload->>'new_status', 'updated'));
    CASE v_status
      WHEN 'assigned' THEN
        v_title := 'Logistics partner assigned';
        v_message := 'A logistics partner has been assigned to your shipment.';
      WHEN 'picked_up' THEN
        v_title := 'Shipment picked up';
        v_message := 'Your shipment has been picked up.';
      WHEN 'in_transit' THEN
        v_title := 'Shipment in transit';
        v_message := 'Your shipment is now in transit.';
      WHEN 'delivered' THEN
        v_title := 'Delivery completed';
        v_message := 'Your shipment has been marked as delivered.';
      WHEN 'cancelled' THEN
        v_title := 'Shipment cancelled';
        v_message := 'Your shipment has been cancelled. Please review the shipment details or contact KRIM support.';
      WHEN 'exception' THEN
        v_title := 'Shipment needs attention';
        v_message := 'An operational exception has been recorded for your shipment. Please check your KRIM workspace.';
      ELSE
        v_title := 'Shipment status updated';
        v_message := 'Your shipment status is now: ' || v_status || '.';
    END CASE;
  END IF;

  INSERT INTO public.notifications (
    user_id, krim_shipment_id, title, message, notification_type,
    is_read, source_event_id
  )
  SELECT DISTINCT m.user_id, v_shipment_id, v_title, v_message,
         'shipment', false, NEW.event_id
  FROM public.krim_organization_members m
  WHERE m.organization_id = v_customer_org_id
    AND m.status = 'active'
  ON CONFLICT (source_event_id, user_id)
    WHERE source_event_id IS NOT NULL
  DO NOTHING;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_shipment_created_in_app_event ON public.krim_shipments;
CREATE TRIGGER trg_krim_shipment_created_in_app_event
AFTER INSERT ON public.krim_shipments
FOR EACH ROW
EXECUTE FUNCTION public.krim_internal_emit_shipment_created_event();

DROP TRIGGER IF EXISTS trg_krim_customer_shipment_in_app_notification ON public.krim_events;
CREATE TRIGGER trg_krim_customer_shipment_in_app_notification
AFTER INSERT ON public.krim_events
FOR EACH ROW
EXECUTE FUNCTION public.krim_internal_create_customer_shipment_in_app_notification();

REVOKE ALL ON FUNCTION public.krim_internal_emit_shipment_created_event() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.krim_internal_create_customer_shipment_in_app_notification() FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON COLUMN public.notifications.source_event_id IS
  'KRIM domain event UUID used for idempotent in-app notification creation.';
