DO $migration$
DECLARE
  v_submit text;
  v_authorize text;
  v_old_submit text := $submit_old$
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery POD; current status %',v_shipment.id,v_shipment.status;
  end if;
 end if;
$submit_old$;
  v_new_submit text := $submit_new$
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery POD; current status %',v_shipment.id,v_shipment.status;
  end if;
  if v_leg.status<>'in_transit' then
   raise exception using errcode='55000',message='Exact shipment leg must be in_transit before POD submission';
  end if;
 end if;
$submit_new$;
  v_old_authorize text := $auth_old$
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery authorization; current status %',v_shipment.id,v_shipment.status;
  end if;
 end if;
$auth_old$;
  v_new_authorize text := $auth_new$
 else
  if v_shipment.status<>'in_transit' then
   raise exception 'Shipment % must be in_transit for delivery authorization; current status %',v_shipment.id,v_shipment.status;
  end if;
  if v_leg.status<>'in_transit' then
   raise exception using errcode='55000',message='Exact shipment leg must be in_transit before delivery authorization';
  end if;
 end if;
$auth_new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)'::regprocedure) INTO v_submit;
  IF position(v_old_submit in v_submit)=0 THEN
    RAISE EXCEPTION 'Expected single-leg POD submission guard not found; migration aborted';
  END IF;
  EXECUTE replace(v_submit,v_old_submit,v_new_submit);

  SELECT pg_get_functiondef('public.krim_internal_authorize_delivery(bigint,uuid)'::regprocedure) INTO v_authorize;
  IF position(v_old_authorize in v_authorize)=0 THEN
    RAISE EXCEPTION 'Expected single-leg delivery authorization guard not found; migration aborted';
  END IF;
  EXECUTE replace(v_authorize,v_old_authorize,v_new_authorize);
END
$migration$;