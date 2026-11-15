-- Make driver evidence array ordering deterministic so exact POD retry fingerprints
-- remain stable when two evidence records share the same creation timestamp.
DO $$
DECLARE v_definition text;
BEGIN
  SELECT pg_get_functiondef('public.krim_driver_submit_delivery_pod(uuid,text,text,text)'::regprocedure)
  INTO v_definition;
  v_definition := replace(v_definition, 'ORDER BY e.created_at)', 'ORDER BY e.created_at,e.id)');
  EXECUTE v_definition;
END;
$$;
