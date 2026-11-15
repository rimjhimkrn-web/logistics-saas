-- Tracking event types are an extensible operational event vocabulary.
-- Do not restrict existing milestone and exception event types with a narrow check list.
ALTER TABLE public.krim_tracking_events
  DROP CONSTRAINT IF EXISTS krim_tracking_event_type_check;
