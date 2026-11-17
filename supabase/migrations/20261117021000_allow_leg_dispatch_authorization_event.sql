-- Allow the dispatch authorization audit event emitted by krim_authorize_leg_dispatch.
-- The existing CHECK constraint omitted this event type, causing the authorization
-- transaction to roll back when it attempted to write its required audit record.
alter table public.krim_partner_execution_events
  drop constraint if exists chk_partner_execution_event_type;

alter table public.krim_partner_execution_events
  add constraint chk_partner_execution_event_type
  check (event_type = any (array[
    'accepted',
    'vehicle_assigned',
    'driver_assigned',
    'pickup_scheduled',
    'arrived_pickup',
    'picked_up',
    'departed',
    'in_transit',
    'arrived_destination',
    'delivered',
    'pod_submitted',
    'pod_verified',
    'exception_reported',
    'execution_completed',
    'leg_dispatch_authorized'
  ]::text[]));

comment on constraint chk_partner_execution_event_type
  on public.krim_partner_execution_events
  is 'Canonical partner execution event types, including exact-leg dispatch authorization audit events.';
