-- Step 1: partner bidding must be authorized by an organization-scoped role permission.
-- Grant quote.create to the partner_user role, then enforce it inside the SECURITY DEFINER RPC.
INSERT INTO public.krim_role_permissions (id, role_id, permission_id, granted)
SELECT 155, 10, 10, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.krim_role_permissions
  WHERE role_id = 10 AND permission_id = 10
);

DO $migration$
DECLARE
  v_oid oid;
  v_definition text;
  v_old text := $old$  IF v_partner_organization_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Only verified organisations with an active approved capability may submit partner bids';
  END IF;
$old$;
  v_new text := $new$  IF v_partner_organization_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Only verified organisations with an active approved capability may submit partner bids';
  END IF;

  IF NOT private.krim_has_permission(v_user_id, v_partner_organization_id, 'quote.create') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Permission denied: partner quote submission requires quote.create';
  END IF;
$new$;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'krim_submit_partner_quote'
    AND pg_get_function_identity_arguments(p.oid) =
      'p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'Expected partner quote submission function was not found';
  END IF;
  v_definition := pg_get_functiondef(v_oid);
  IF position('partner quote submission requires quote.create' IN v_definition) > 0 THEN
    NULL;
  ELSIF position(v_old IN v_definition) > 0 THEN
    v_definition := replace(v_definition, v_old, v_new);
    EXECUTE v_definition;
  ELSE
    RAISE EXCEPTION 'Partner quote permission insertion point did not match; migration aborted safely';
  END IF;
END
$migration$;
