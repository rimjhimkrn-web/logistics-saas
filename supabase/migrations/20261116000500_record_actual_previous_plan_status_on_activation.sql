-- Preserve the actual pre-activation plan status in the plan audit event.
DO $migration$
DECLARE
  v_def text;
  v_old text := $old$p_plan_id,'plan_activated','draft','active',v_user,$old$;
  v_new text := $new$p_plan_id,'plan_activated',v_plan.status,'active',v_user,$new$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef('public.krim_activate_shipment_leg_plan(bigint,text)'::regprocedure) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN
    RAISE EXCEPTION 'Expected plan activation audit status expression not found';
  END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);
END
$migration$;
