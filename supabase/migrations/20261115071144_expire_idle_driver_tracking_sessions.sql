CREATE OR REPLACE FUNCTION private.krim_internal_expire_stale_driver_tracking_sessions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_expired integer := 0;
BEGIN
  WITH stale_sessions AS (
    SELECT s.id
    FROM public.krim_driver_tracking_sessions s
    WHERE s.status = 'active'
      AND coalesce((
        SELECT max(e.event_time)
        FROM public.krim_tracking_events e
        WHERE e.shipment_id = s.shipment_id
          AND e.assignment_id = s.partner_assignment_id
          AND e.source_type = 'gps'
          AND e.event_type = 'gps_position'
          AND e.metadata ->> 'tracking_session_id' = s.id::text
      ), s.started_at) <= now() - interval '15 minutes'
  )
  UPDATE public.krim_driver_tracking_sessions s
  SET status = 'stopped',
      stopped_at = now(),
      stop_reason = 'inactivity_timeout'
  FROM stale_sessions stale
  WHERE s.id = stale.id
    AND s.status = 'active';

  GET DIAGNOSTICS v_expired = ROW_COUNT;
  RETURN v_expired;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_internal_expire_stale_driver_tracking_sessions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.krim_internal_expire_stale_driver_tracking_sessions() TO service_role;

DO $schedule$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'krim-driver-tracking-session-idle-expiry'
  LIMIT 1;
  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;
  PERFORM cron.schedule(
    'krim-driver-tracking-session-idle-expiry',
    '*/5 * * * *',
    'SELECT private.krim_internal_expire_stale_driver_tracking_sessions();'
  );
END;
$schedule$;
