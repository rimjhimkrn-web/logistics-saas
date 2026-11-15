DROP POLICY IF EXISTS "Drivers read own GPS tracking events" ON public.krim_tracking_events;
DROP POLICY IF EXISTS "KRIM tracking events scoped read" ON public.krim_tracking_events;
CREATE POLICY "KRIM tracking events scoped read"
ON public.krim_tracking_events
FOR SELECT
TO authenticated
USING (
  private.krim_user_has_active_partner_assignment(shipment_id)
  OR EXISTS (
    SELECT 1
    FROM public.krim_shipments s
    WHERE s.id = krim_tracking_events.shipment_id
      AND s.customer_organization_id IS NOT NULL
      AND private.krim_has_organization_access((SELECT auth.uid()), s.customer_organization_id)
  )
  OR EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id = m.organization_id
    WHERE m.user_id = (SELECT auth.uid())
      AND m.status = 'active'
      AND o.status = 'active'
      AND lower(COALESCE(o.organization_type, '')) = 'operations'
      AND public.krim_has_permission((SELECT auth.uid()), m.organization_id, 'tracking.view')
  )
  OR EXISTS (
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
CREATE INDEX IF NOT EXISTS krim_driver_tracking_sessions_org_recent_idx
  ON public.krim_driver_tracking_sessions(organization_id,started_at DESC);
CREATE INDEX IF NOT EXISTS krim_driver_tracking_sessions_partner_assignment_idx
  ON public.krim_driver_tracking_sessions(partner_assignment_id);
