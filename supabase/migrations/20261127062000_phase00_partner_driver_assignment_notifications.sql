-- Phase 00: emit partner and driver assignment lifecycle events and create in-app alerts.
-- Only in-app delivery is enabled; external channels remain gated.

CREATE OR REPLACE FUNCTION public.krim_internal_emit_partner_assignment_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_event_type text;
  v_payload jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := 'partner.assignment_offered';
    v_payload := jsonb_build_object(
      'assignment_id', NEW.id, 'shipment_id', NEW.shipment_id,
      'shipment_leg_id', NEW.shipment_leg_id,
      'partner_organization_id', NEW.partner_organization_id,
      'assignment_number', NEW.assignment_number, 'status', NEW.status
    );
  ELSE
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
    v_event_type := 'partner.assignment_status_changed';
    v_payload := jsonb_build_object(
      'assignment_id', NEW.id, 'shipment_id', NEW.shipment_id,
      'shipment_leg_id', NEW.shipment_leg_id,
      'partner_organization_id', NEW.partner_organization_id,
      'assignment_number', NEW.assignment_number,
      'previous_status', OLD.status, 'new_status', NEW.status
    );
  END IF;

  INSERT INTO public.krim_events (
    event_id, organization_id, entity_type, entity_id, event_type,
    event_version, source, actor_user_id, occurred_at, payload, metadata,
    processing_status, processing_attempts, created_at
  ) VALUES (
    gen_random_uuid(), NEW.partner_organization_id, 'partner_assignment',
    NEW.id, v_event_type, 1, 'partner_assignment.lifecycle', auth.uid(),
    clock_timestamp(), v_payload,
    jsonb_build_object('trigger','krim_partner_assignment_in_app_event'),
    'pending', 0, clock_timestamp()
  );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_emit_driver_assignment_event()
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
  ) VALUES (
    gen_random_uuid(), NEW.organization_id, 'driver_assignment', NULL,
    'driver.assignment_created', 1, 'driver_assignment.created', auth.uid(),
    clock_timestamp(),
    jsonb_build_object(
      'driver_assignment_id', NEW.id, 'driver_user_id', NEW.user_id,
      'partner_assignment_id', NEW.partner_assignment_id,
      'shipment_id', NEW.shipment_id, 'shipment_leg_id', NEW.shipment_leg_id,
      'assignment_number', NEW.assignment_number, 'status', NEW.status
    ),
    jsonb_build_object('trigger','krim_driver_assignment_in_app_event'),
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
  v_partner_org_id bigint;
  v_driver_user_id uuid;
  v_assignment_id bigint;
  v_driver_assignment_id uuid;
  v_title text;
  v_message text;
  v_status text;
BEGIN
  IF NEW.event_type IN ('shipment.created','shipment.status_changed')
     AND NEW.entity_type = 'shipment' THEN
    v_shipment_id := COALESCE((NEW.payload->>'shipment_id')::bigint, NEW.entity_id);
    SELECT s.customer_organization_id INTO v_customer_org_id
    FROM public.krim_shipments s
    WHERE s.id = v_shipment_id AND s.customer_organization_id = NEW.organization_id;
    IF v_customer_org_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.krim_organizations o
      WHERE o.id = v_customer_org_id
        AND o.organization_type IN ('customer','enterprise') AND o.status='active'
    ) THEN RETURN NEW; END IF;

    IF NEW.event_type = 'shipment.created' THEN
      v_title := 'Booking received';
      v_message := 'Your shipment booking '||COALESCE(NEW.payload->>'shipment_number','request')||
        ' has been created. You can follow its progress in your KRIM workspace.';
    ELSE
      v_status := lower(COALESCE(NEW.payload->>'new_status','updated'));
      CASE v_status
        WHEN 'assigned' THEN v_title:='Logistics partner assigned'; v_message:='A logistics partner has been assigned to your shipment.';
        WHEN 'picked_up' THEN v_title:='Shipment picked up'; v_message:='Your shipment has been picked up.';
        WHEN 'in_transit' THEN v_title:='Shipment in transit'; v_message:='Your shipment is now in transit.';
        WHEN 'delivered' THEN v_title:='Delivery completed'; v_message:='Your shipment has been marked as delivered.';
        WHEN 'cancelled' THEN v_title:='Shipment cancelled'; v_message:='Your shipment has been cancelled. Please review the shipment details or contact KRIM support.';
        WHEN 'exception' THEN v_title:='Shipment needs attention'; v_message:='An operational exception has been recorded for your shipment. Please check your KRIM workspace.';
        ELSE v_title:='Shipment status updated'; v_message:='Your shipment status is now: '||v_status||'.';
      END CASE;
    END IF;

    INSERT INTO public.notifications(user_id,krim_shipment_id,title,message,notification_type,is_read,source_event_id)
    SELECT DISTINCT m.user_id,v_shipment_id,v_title,v_message,'shipment',false,NEW.event_id
    FROM public.krim_organization_members m
    WHERE m.organization_id=v_customer_org_id AND m.status='active'
    ON CONFLICT (source_event_id,user_id) WHERE source_event_id IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  IF NEW.event_type IN ('partner.assignment_offered','partner.assignment_status_changed')
     AND NEW.entity_type = 'partner_assignment' THEN
    v_assignment_id := COALESCE((NEW.payload->>'assignment_id')::bigint, NEW.entity_id);
    SELECT a.partner_organization_id,a.shipment_id
      INTO v_partner_org_id,v_shipment_id
    FROM public.krim_shipment_partner_assignments a
    WHERE a.id=v_assignment_id
      AND a.partner_organization_id=NEW.organization_id;
    IF v_partner_org_id IS NULL THEN RETURN NEW; END IF;

    IF NEW.event_type='partner.assignment_offered' THEN
      v_title:='New shipment assignment';
      v_message:='A shipment assignment is awaiting your review.';
    ELSE
      v_status:=lower(COALESCE(NEW.payload->>'new_status','updated'));
      v_title:='Assignment status updated';
      v_message:='Your shipment assignment status is now: '||v_status||'.';
    END IF;

    INSERT INTO public.notifications(user_id,krim_shipment_id,title,message,notification_type,is_read,source_event_id)
    SELECT DISTINCT m.user_id,v_shipment_id,v_title,v_message,'partner_assignment',false,NEW.event_id
    FROM public.krim_organization_members m
    WHERE m.organization_id=v_partner_org_id AND m.status='active'
    ON CONFLICT (source_event_id,user_id) WHERE source_event_id IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  IF NEW.event_type='driver.assignment_created' AND NEW.entity_type='driver_assignment' THEN
    v_driver_assignment_id := (NEW.payload->>'driver_assignment_id')::uuid;
    SELECT da.user_id,da.shipment_id
      INTO v_driver_user_id,v_shipment_id
    FROM public.krim_driver_assignments da
    WHERE da.id=v_driver_assignment_id
      AND da.organization_id=NEW.organization_id
      AND da.user_id=(NEW.payload->>'driver_user_id')::uuid
      AND da.partner_assignment_id=(NEW.payload->>'partner_assignment_id')::bigint
      AND da.shipment_id=(NEW.payload->>'shipment_id')::bigint
      AND da.shipment_leg_id=(NEW.payload->>'shipment_leg_id')::bigint;
    IF v_driver_user_id IS NULL THEN RETURN NEW; END IF;

    INSERT INTO public.notifications(user_id,krim_shipment_id,title,message,notification_type,is_read,source_event_id)
    VALUES (v_driver_user_id,v_shipment_id,'New delivery assignment',
      'A shipment has been assigned to you. Review the pickup, delivery and shipment details in your KRIM Drive workspace.',
      'driver_assignment',false,NEW.event_id)
    ON CONFLICT (source_event_id,user_id) WHERE source_event_id IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_partner_assignment_in_app_event ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_partner_assignment_in_app_event
AFTER INSERT OR UPDATE ON public.krim_shipment_partner_assignments
FOR EACH ROW EXECUTE FUNCTION public.krim_internal_emit_partner_assignment_event();

DROP TRIGGER IF EXISTS trg_krim_driver_assignment_in_app_event ON public.krim_driver_assignments;
CREATE TRIGGER trg_krim_driver_assignment_in_app_event
AFTER INSERT ON public.krim_driver_assignments
FOR EACH ROW EXECUTE FUNCTION public.krim_internal_emit_driver_assignment_event();

REVOKE ALL ON FUNCTION public.krim_internal_emit_partner_assignment_event() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.krim_internal_emit_driver_assignment_event() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.krim_internal_create_customer_shipment_in_app_notification() FROM PUBLIC,anon,authenticated,service_role;
