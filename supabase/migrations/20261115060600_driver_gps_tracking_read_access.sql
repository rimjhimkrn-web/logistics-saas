ALTER TABLE public.krim_tracking_events
  DROP CONSTRAINT IF EXISTS krim_tracking_event_type_check;
ALTER TABLE public.krim_tracking_events
  ADD CONSTRAINT krim_tracking_event_type_check
  CHECK (event_type = ANY (ARRAY[
    'created','confirmed','assigned','picked_up','departed','arrived',
    'in_transit','delayed','customs_hold','out_for_delivery','delivered',
    'cancelled','exception','gps_position'
  ]::text[]));

DROP POLICY IF EXISTS "Drivers read own GPS tracking events" ON public.krim_tracking_events;
CREATE POLICY "Drivers read own GPS tracking events"
ON public.krim_tracking_events
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.krim_driver_assignments d
    JOIN public.krim_organization_members m
      ON m.organization_id = d.organization_id
     AND m.user_id = (SELECT auth.uid())
     AND m.role = 'driver'
     AND m.status = 'active'
    JOIN public.krim_organizations o
      ON o.id = d.organization_id
     AND o.status = 'active'
    WHERE d.user_id = (SELECT auth.uid())
      AND d.partner_assignment_id = krim_tracking_events.assignment_id
      AND d.shipment_id = krim_tracking_events.shipment_id
      AND d.organization_id = krim_tracking_events.partner_organization_id
  )
);
