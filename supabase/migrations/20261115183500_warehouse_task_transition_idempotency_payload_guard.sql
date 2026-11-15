DO $migration$
DECLARE
 v_def text;
 v_old text;
 v_new text;
BEGIN
 v_def:=pg_get_functiondef('public.krim_warehouse_transition_task(uuid,text,uuid,text)'::regprocedure);
 v_old:=$old$DECLARE v_user uuid:=auth.uid(); v_task public.krim_warehouse_tasks%rowtype; v_movement jsonb; v_old text;$old$;
 v_new:=$new$DECLARE v_user uuid:=auth.uid(); v_task public.krim_warehouse_tasks%rowtype; v_movement jsonb; v_old text;
 v_prior_event public.krim_warehouse_task_events%rowtype;$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Warehouse task transition declaration anchor changed'; END IF;
 v_def:=replace(v_def,v_old,v_new);
 v_old:=$old$ IF EXISTS(SELECT 1 FROM public.krim_warehouse_task_events e WHERE e.task_id=v_task.id AND e.metadata->>'transition_key'=p_idempotency_key::text)
 THEN RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task)); END IF;$old$;
 v_new:=$new$ SELECT * INTO v_prior_event FROM public.krim_warehouse_task_events e
 WHERE e.task_id=v_task.id AND e.metadata->>'transition_key'=p_idempotency_key::text
 ORDER BY e.created_at DESC LIMIT 1;
 IF FOUND THEN
  IF v_prior_event.new_status IS DISTINCT FROM p_new_status
    OR coalesce(v_prior_event.metadata->>'notes','')<>left(coalesce(p_notes,''),1000) THEN
   RAISE EXCEPTION 'Transition idempotency key was already used for a different status or note' USING errcode='23505';
  END IF;
  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;$new$;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'Warehouse task transition replay anchor changed'; END IF;
 v_def:=replace(v_def,v_old,v_new);
 EXECUTE v_def;
END;
$migration$;
