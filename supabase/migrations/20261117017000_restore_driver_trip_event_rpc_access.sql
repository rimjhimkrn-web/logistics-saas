-- Allow authenticated drivers to record only their own guarded trip milestones.
-- The function enforces active driver membership, assignment ownership, accepted
-- driver assignment, dispatch readiness and ordered pickup/transit transitions.
REVOKE ALL ON FUNCTION public.krim_driver_record_trip_event(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_record_trip_event(uuid,text,text) TO authenticated;
