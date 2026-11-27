ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'delivered',
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS read_at timestamptz;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_delivery_status_valid;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_delivery_status_valid
  CHECK (delivery_status IN ('delivered','read'));

CREATE INDEX IF NOT EXISTS idx_notifications_user_delivery_history
  ON public.notifications(user_id,created_at DESC,id DESC);

CREATE OR REPLACE FUNCTION public.krim_sync_in_app_notification_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog,public,auth
AS $function$
BEGIN
  IF TG_OP='INSERT' THEN
    NEW.delivery_status := CASE WHEN COALESCE(NEW.is_read,false) THEN 'read' ELSE 'delivered' END;
    NEW.delivered_at := COALESCE(NEW.delivered_at,now());
    NEW.read_at := CASE WHEN COALESCE(NEW.is_read,false) THEN COALESCE(NEW.read_at,now()) ELSE NULL END;
    RETURN NEW;
  END IF;

  -- Authenticated users may only change their own read state, never rewrite notification history.
  IF auth.uid() IS NOT NULL THEN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.shipment_id IS DISTINCT FROM OLD.shipment_id
      OR NEW.krim_shipment_id IS DISTINCT FROM OLD.krim_shipment_id
      OR NEW.title IS DISTINCT FROM OLD.title
      OR NEW.message IS DISTINCT FROM OLD.message
      OR NEW.notification_type IS DISTINCT FROM OLD.notification_type
      OR NEW.source_event_id IS DISTINCT FROM OLD.source_event_id
      OR NEW.delivered_at IS DISTINCT FROM OLD.delivered_at
      OR NEW.delivery_status IS DISTINCT FROM OLD.delivery_status
      OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'notification_history_is_immutable';
    END IF;
  END IF;

  IF NEW.is_read IS DISTINCT FROM OLD.is_read THEN
    IF NEW.is_read THEN
      NEW.read_at := COALESCE(NEW.read_at,now());
      NEW.delivery_status := 'read';
    ELSE
      NEW.read_at := NULL;
      NEW.delivery_status := 'delivered';
    END IF;
  ELSE
    NEW.read_at := OLD.read_at;
    NEW.delivery_status := OLD.delivery_status;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_sync_in_app_notification_history ON public.notifications;
CREATE TRIGGER trg_krim_sync_in_app_notification_history
BEFORE INSERT OR UPDATE ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.krim_sync_in_app_notification_history();

REVOKE ALL ON FUNCTION public.krim_sync_in_app_notification_history() FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON COLUMN public.notifications.delivery_status IS 'Persisted in-app state: delivered when created; read after recipient marks it read.';
COMMENT ON COLUMN public.notifications.delivered_at IS 'Timestamp when the in-app notification record was committed.';
COMMENT ON COLUMN public.notifications.read_at IS 'Timestamp when the recipient marked the notification read.';
