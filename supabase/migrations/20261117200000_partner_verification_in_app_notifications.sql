-- Deliver partner verification information requests to the submitting partner's in-app inbox.
-- The notifications table is already RLS-enabled with user_id-scoped SELECT/UPDATE policies.
grant select, update on table public.notifications to authenticated;

do $patch$
declare
  v_definition text;
  v_old_declaration text := $old$  v_case_status text;
  v_mode text;$old$;
  v_new_declaration text := $new$  v_case_status text;
  v_mode text;
  v_recipient_user_id uuid;$new$;
  v_old_select text := $old$select c.organization_id,c.status,o.partner_account_mode,$old$;
  v_new_select text := $new$select c.organization_id,c.status,o.partner_account_mode,c.submitted_by,$new$;
  v_old_into text := $old$into v_org_id,v_case_status,v_mode,v_old_state$old$;
  v_new_into text := $new$into v_org_id,v_case_status,v_mode,v_recipient_user_id,v_old_state$new$;
  v_old_return text := $old$  return jsonb_build_object($old$;
  v_new_return text := $new$  if v_recipient_user_id is not null
     and (v_case_status <> 'pending_information'
          or v_old_state->>'decision_reason' is distinct from v_request) then
    insert into public.notifications(user_id,title,message,notification_type,is_read)
    values(v_recipient_user_id,
      'Additional information required for your KRIM partner application',
      v_request,'alert',false);
  end if;

  return jsonb_build_object($new$;
begin
  select pg_get_functiondef('public.krim_admin_request_partner_verification_information(bigint,text)'::regprocedure)
    into v_definition;
  if position(v_old_declaration in v_definition)=0
     or position(v_old_select in v_definition)=0
     or position(v_old_into in v_definition)=0
     or position(v_old_return in v_definition)=0 then
    raise exception 'Expected partner verification notification insertion points were not found; refusing to patch';
  end if;
  v_definition:=replace(v_definition,v_old_declaration,v_new_declaration);
  v_definition:=replace(v_definition,v_old_select,v_new_select);
  v_definition:=replace(v_definition,v_old_into,v_new_into);
  v_definition:=replace(v_definition,v_old_return,v_new_return);
  execute v_definition;
end
$patch$;
