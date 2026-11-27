-- A worker may start with a valid lease but run past its expiry.
-- Recheck wall-clock lease validity at commit and raise so all action-side writes roll back.
DO $$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef('public.krim_internal_execute_workflow_action(bigint,uuid)'::regprocedure)
    INTO v_def;
  v_def := replace(v_def, 'lease_expires_at>v_now', 'lease_expires_at>clock_timestamp()');
  v_def := replace(v_def,
    E'IF NOT FOUND THEN\n    RETURN jsonb_build_object(''ok'',false,''status'',''rejected'',''error_code'',''LEASE_LOST_DURING_EXECUTION'');\n  END IF;',
    E'IF NOT FOUND THEN\n    RAISE EXCEPTION ''LEASE_LOST_DURING_EXECUTION'' USING ERRCODE=''40001'';\n  END IF;');
  IF position('lease_expires_at>clock_timestamp()' in v_def)=0
     OR position('RAISE EXCEPTION ''LEASE_LOST_DURING_EXECUTION''' in v_def)=0 THEN
    RAISE EXCEPTION 'workflow_executor_patch_pattern_not_found';
  END IF;
  EXECUTE v_def;
END $$;
