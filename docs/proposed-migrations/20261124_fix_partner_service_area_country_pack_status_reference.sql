-- Proposed forward-only production repair.
-- Fixes a confirmed invalid column reference in the partner service-area approval RPC.
-- Do not apply until migration-ledger reconciliation and release approval are complete.

DO $patch$
DECLARE
  v_definition text;
  v_old text := $old$cp.status='approved'$old$;
  v_new text := $new$cp.pack_status='approved'$new$;
  v_occurrences integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='krim_country_operating_packs'
      AND column_name='pack_status'
  ) THEN
    RAISE EXCEPTION 'Expected public.krim_country_operating_packs.pack_status column is missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='krim_country_operating_packs'
      AND column_name='status'
  ) THEN
    RAISE EXCEPTION 'Unexpected status column exists; review the target schema before applying this repair';
  END IF;

  SELECT pg_get_functiondef(
    'public.krim_admin_review_partner_service_area(bigint,text,text)'::regprocedure
  ) INTO v_definition;

  IF position(v_new IN v_definition)>0 AND position(v_old IN v_definition)=0 THEN
    -- Already repaired: make the migration safe to re-run.
    RETURN;
  END IF;

  v_occurrences := (length(v_definition)-length(replace(v_definition,v_old,''))) / length(v_old);
  IF v_occurrences<>1 THEN
    RAISE EXCEPTION 'Expected exactly one cp.status=approved reference in krim_admin_review_partner_service_area; found %',v_occurrences;
  END IF;

  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;

  SELECT pg_get_functiondef(
    'public.krim_admin_review_partner_service_area(bigint,text,text)'::regprocedure
  ) INTO v_definition;

  IF position(v_new IN v_definition)=0 OR position(v_old IN v_definition)>0 THEN
    RAISE EXCEPTION 'Partner service-area review function column-reference repair did not verify';
  END IF;
END
$patch$;
