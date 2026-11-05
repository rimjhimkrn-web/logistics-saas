-- Enforce AAL2 at the database boundary for every global rate-card administration RPC.
-- UI checks are not an authorization boundary; direct RPC calls must independently require AAL2.
DO $migration$
DECLARE
  v_signature text;
  v_oid oid;
  v_definition text;
  v_old text := 'IF auth.uid() IS NULL THEN RAISE EXCEPTION USING errcode=''28000'',message=''Authentication required''; END IF;';
  v_new text := v_old || E'\n IF coalesce(auth.jwt()->>''aal'',''aal1'') <> ''aal2'' THEN RAISE EXCEPTION USING errcode=''42501'',message=''AAL2 required''; END IF;';
  v_signatures text[] := ARRAY[
    'public.krim_admin_list_global_rate_cards()',
    'public.krim_admin_create_global_rate_card(bigint,bigint,text,text,text,numeric,text,numeric,timestamp with time zone,timestamp with time zone,integer)',
    'public.krim_admin_record_global_rate_card_evidence(bigint,bigint,numeric,numeric,text,date,text,text)',
    'public.krim_admin_approve_global_rate_card(bigint,text)',
    'public.krim_admin_set_global_rate_card_status(bigint,text)'
  ];
BEGIN
  FOREACH v_signature IN ARRAY v_signatures LOOP
    v_oid := to_regprocedure(v_signature);
    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'Required pricing administration function missing: %', v_signature;
    END IF;
    v_definition := pg_get_functiondef(v_oid);
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'Expected authentication guard not found in %; no function changed', v_signature;
    END IF;
    IF position('auth.jwt()->>''aal''' IN v_definition) > 0 THEN
      RAISE EXCEPTION 'AAL claim guard already exists in %; review before applying', v_signature;
    END IF;
    v_definition := replace(v_definition, v_old, v_new);
    EXECUTE v_definition;
  END LOOP;
END
$migration$;