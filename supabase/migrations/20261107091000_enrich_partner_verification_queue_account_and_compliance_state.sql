-- Expose authoritative organisation account, verification, compliance and lifecycle
-- state to the MFA-protected partner verification queue.
DO $migration$
DECLARE
  v_def text;
  v_old text := $old$c.metadata, o.partner_metadata$old$;
  v_new text := $new$c.metadata,
         coalesce(o.partner_metadata,'{}'::jsonb) || jsonb_build_object(
           'account_mode',o.partner_account_mode,
           'partner_verification_status',o.partner_verification_status,
           'partner_compliance_status',o.partner_compliance_status,
           'partner_lifecycle_status',o.partner_lifecycle_status
         )$new$;
BEGIN
  SELECT pg_get_functiondef('public.krim_admin_list_partner_verification_cases()'::regprocedure)
    INTO v_def;
  IF position(v_new in v_def)>0 THEN RETURN; END IF;
  IF position(v_old in v_def)=0 THEN
    RAISE EXCEPTION 'Expected partner verification queue metadata projection not found';
  END IF;
  EXECUTE replace(v_def,v_old,v_new);
END
$migration$;
