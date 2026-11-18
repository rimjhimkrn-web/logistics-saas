-- Expose the latest partner-facing review request in the restricted admin queue.
do $patch$
declare
  v_definition text;
  v_old text := $old$o.partner_lifecycle_status$old$;
  v_new text := $new$o.partner_lifecycle_status,
           'partner_review_notes',o.partner_review_notes,
           'partner_onboarding_status',o.partner_onboarding_status$new$;
begin
  select pg_get_functiondef('public.krim_admin_list_partner_verification_cases()'::regprocedure)
    into v_definition;
  if position(v_old in v_definition)=0 then
    raise exception 'Expected admin queue organization metadata field missing; refusing to patch';
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
  execute v_definition;
end
$patch$;
