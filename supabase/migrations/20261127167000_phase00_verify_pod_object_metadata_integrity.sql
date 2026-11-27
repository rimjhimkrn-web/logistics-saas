DO $migration$
DECLARE
  v_submit text;
  v_review text;
  v_old_submit text := $oldsubmit$
   AND o.owner=v_user
$oldsubmit$;
  v_new_submit text := $newsubmit$
   AND o.owner=v_user
   AND o.metadata->>'mimetype'=e.content_type
   AND o.metadata->>'size'=e.file_size::text
$newsubmit$;
  v_old_review text := $oldreview$
    and o.owner=da.user_id
$oldreview$;
  v_new_review text := $newreview$
    and o.owner=da.user_id
    and o.metadata->>'mimetype'=e.content_type
    and o.metadata->>'size'=e.file_size::text
$newreview$;
BEGIN
  SELECT pg_get_functiondef('public.krim_driver_submit_delivery_pod(uuid,text,text,text)'::regprocedure) INTO v_submit;
  IF position(v_old_submit in v_submit)=0 THEN
    RAISE EXCEPTION 'Expected driver evidence object-owner join not found; migration aborted';
  END IF;
  EXECUTE replace(v_submit,v_old_submit,v_new_submit);

  SELECT pg_get_functiondef('public.krim_admin_review_delivery_pod(bigint,text,text)'::regprocedure) INTO v_review;
  IF position(v_old_review in v_review)=0 THEN
    RAISE EXCEPTION 'Expected admin evidence object-owner join not found; migration aborted';
  END IF;
  EXECUTE replace(v_review,v_old_review,v_new_review);
END
$migration$;