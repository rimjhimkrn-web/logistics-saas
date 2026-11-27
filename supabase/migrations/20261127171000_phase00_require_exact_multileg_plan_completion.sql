DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
  select v_plan_item_count=v_plan.total_legs
    and v_materialized_leg_count=v_plan.total_legs
    and not exists(select 1 from public.krim_shipment_legs l
      where l.shipment_id=v_shipment.id and l.status not in('completed','delivered'))
   into v_final_leg;
$old$;
  v_new text := $new$
  select v_plan_item_count=v_plan.total_legs
    and v_materialized_leg_count=v_plan.total_legs
    and not exists(select 1 from public.krim_shipment_legs l
      where l.shipment_id=v_shipment.id and l.status not in('completed','delivered'))
    and not exists(
      select 1
      from public.krim_shipment_leg_plan_items i
      where i.plan_id=v_plan.id
        and (select count(*) from public.krim_shipment_legs l
             where l.shipment_id=v_shipment.id
               and l.leg_plan_item_id=i.id
               and l.status in('completed','delivered')) <> 1
    )
   into v_final_leg;
$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_internal_authorize_delivery(bigint,uuid)'::regprocedure)
  INTO v_definition;
  IF position(v_old in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected multi-leg completion calculation not found; migration aborted';
  END IF;
  EXECUTE replace(v_definition,v_old,v_new);
END
$migration$;