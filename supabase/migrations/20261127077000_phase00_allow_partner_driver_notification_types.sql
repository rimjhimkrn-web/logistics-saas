ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_notification_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_notification_type_check
  CHECK (notification_type IN (
    'general','shipment','quote','payment','dispatch','delivery','alert',
    'partner_assignment','driver_assignment'
  ));

COMMENT ON CONSTRAINT notifications_notification_type_check ON public.notifications
IS 'Allows the notification categories emitted by customer, partner and driver shipment event handlers.';
