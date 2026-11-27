DO $migration$
DECLARE
 v_submit text;
 v_authorize text;
 v_old text := $old$
 v_is_active_multileg:=found;
$old$;
 v_new text := $new$
 v_is_active_multileg:=found;
 if not v_is_active_multileg and (
  exists(select 1 from public.krim_shipment_leg_plans p
   where p.shipment_id=v_shipment.id and p.total_legs>1)
  or (select count(*) from public.krim_shipment_legs l
      where l.shipment_id=v_shipment.id)>1
 ) then
  raise exception using errcode='55000',
   message='Multi-leg shipment requires a valid active multi-leg route plan; single-leg fallback is blocked';
 end if;
$new$;
BEGIN
 SELECT pg_get_functiondef('public.krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)'::regprocedure) INTO v_submit;
 IF position(v_old in v_submit)=0 THEN RAISE EXCEPTION 'POD submission plan selector not found'; END IF;
 EXECUTE replace(v_submit,v_old,v_new);
 SELECT pg_get_functiondef('public.krim_internal_authorize_delivery(bigint,uuid)'::regprocedure) INTO v_authorize;
 IF position(v_old in v_authorize)=0 THEN RAISE EXCEPTION 'Delivery authorization plan selector not found'; END IF;
 EXECUTE replace(v_authorize,v_old,v_new);
END
$migration$;