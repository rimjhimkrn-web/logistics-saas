CREATE TABLE IF NOT EXISTS public.krim_driver_tracking_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_assignment_id uuid NOT NULL REFERENCES public.krim_driver_assignments(id) ON DELETE RESTRICT,
  partner_assignment_id bigint NOT NULL REFERENCES public.krim_shipment_partner_assignments(id) ON DELETE RESTRICT,
  shipment_id bigint NOT NULL REFERENCES public.krim_shipments(id) ON DELETE RESTRICT,
  shipment_leg_id bigint,
  organization_id bigint NOT NULL REFERENCES public.krim_organizations(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  consent_version text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('android','ios','web')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','stopped')),
  consented_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz NOT NULL DEFAULT now(),
  stopped_at timestamptz,
  stop_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT krim_driver_tracking_session_stop_state
    CHECK ((status='active' AND stopped_at IS NULL) OR (status='stopped' AND stopped_at IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS krim_driver_tracking_one_active_session_per_assignment
  ON public.krim_driver_tracking_sessions(driver_assignment_id) WHERE status='active';
CREATE INDEX IF NOT EXISTS krim_driver_tracking_sessions_user_recent_idx
  ON public.krim_driver_tracking_sessions(user_id,started_at DESC);
CREATE INDEX IF NOT EXISTS krim_driver_tracking_sessions_shipment_recent_idx
  ON public.krim_driver_tracking_sessions(shipment_id,started_at DESC);
ALTER TABLE public.krim_driver_tracking_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Drivers read own tracking consent sessions" ON public.krim_driver_tracking_sessions;
CREATE POLICY "Drivers read own tracking consent sessions"
  ON public.krim_driver_tracking_sessions FOR SELECT TO authenticated
  USING (user_id=(SELECT auth.uid()));
REVOKE ALL ON TABLE public.krim_driver_tracking_sessions FROM anon, authenticated;
GRANT SELECT ON TABLE public.krim_driver_tracking_sessions TO authenticated;
GRANT ALL ON TABLE public.krim_driver_tracking_sessions TO service_role;
