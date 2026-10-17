-- Report missing allocation policy separately from an idempotent retry.
DO $migration$
DECLARE
  v_definition text;
  v_old_decl text := '  v_count integer := 0;' || E'\n' || '  v_inserted integer := 0;';
  v_new_decl text := '  v_count integer := 0;' || E'\n' || '  v_rule_count integer := 0;' || E'\n' || '  v_inserted integer := 0;';
  v_old_loop text := '  LOOP' || E'\n' || '    IF r.percentage IS NOT NULL THEN';
  v_new_loop text := '  LOOP' || E'\n' || '    v_rule_count := v_rule_count + 1;' || E'\n' || '    IF r.percentage IS NOT NULL THEN';
  v_old_return text := 'RETURN jsonb_build_object(''ok'', true, ''planned_allocations'', v_count, ''idempotent'', v_count = 0);';
  v_new_return text := 'RETURN jsonb_build_object(''ok'', true, ''planned_allocations'', v_count, ''rule_count'', v_rule_count, ''idempotent'', v_rule_count > 0 AND v_count = 0, ''awaiting_policy'', v_rule_count = 0);';
BEGIN
  v_definition := pg_get_functiondef('krim_internal.plan_revenue_allocation(bigint,bigint,bigint,numeric,text)'::regprocedure);
  IF position('v_rule_count integer := 0;' IN v_definition) > 0 THEN
    RETURN;
  END IF;
  IF position(v_old_decl IN v_definition) = 0 OR position(v_old_loop IN v_definition) = 0 OR position(v_old_return IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected revenue planner structure not found; aborting migration';
  END IF;
  v_definition := replace(v_definition, v_old_decl, v_new_decl);
  v_definition := replace(v_definition, v_old_loop, v_new_loop);
  v_definition := replace(v_definition, v_old_return, v_new_return);
  EXECUTE v_definition;
END
$migration$;
