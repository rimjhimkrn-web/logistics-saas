-- Phase 00: schedule bounded cleanup of expired capacity holds.
DO $migration$
DECLARE
  v_job_id bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is required for capacity hold expiry scheduling';
  END IF;

  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname='krim-capacity-hold-expiry-staging'
  LIMIT 1;

  IF v_job_id IS NULL THEN
    PERFORM cron.schedule(
      'krim-capacity-hold-expiry-staging',
      '* * * * *',
      'SELECT public.krim_internal_expire_capacity_holds(200);'
    );
  ELSE
    UPDATE cron.job
    SET schedule='* * * * *',
        command='SELECT public.krim_internal_expire_capacity_holds(200);',
        active=true
    WHERE jobid=v_job_id;
  END IF;
END
$migration$;
