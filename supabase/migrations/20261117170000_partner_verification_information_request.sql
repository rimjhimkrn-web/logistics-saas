-- Allow administrators to request missing partner verification information
-- without rejecting or closing the existing application.
create or replace function public.krim_admin_request_partner_verification_information(
  p_case_id bigint,
  p_request text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_case_status text;
  v_mode text;
  v_old_state jsonb;
  v_request text := nullif(btrim(coalesce(p_request,'')),'');
  v_new_state jsonb;
begin
  if v_user_id is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='Multi-factor authentication required';
  end if;
  if not private.krim_has_permission(v_user_id, 1::bigint, 'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_case_id is null or v_request is null or char_length(v_request)<10 then
    raise exception using errcode='22023', message='Explain the missing information in at least 10 characters';
  end if;
  if char_length(v_request)>1000 then
    raise exception using errcode='22023', message='Information request must be 1000 characters or fewer';
  end if;

  select c.organization_id,c.status,o.partner_account_mode,
         jsonb_build_object(
           'case_status',c.status,
           'decision',c.decision,
           'decision_reason',c.decision_reason,
           'verification_status',o.partner_verification_status,
           'lifecycle_status',o.partner_lifecycle_status,
           'onboarding_status',o.partner_onboarding_status
         )
    into v_org_id,v_case_status,v_mode,v_old_state
  from public.krim_partner_verification_cases c
  join public.krim_organizations o on o.id=c.organization_id
  where c.id=p_case_id
  for update of c
  for update of o;

  if v_org_id is null then
    raise exception using errcode='P0002', message='Verification case not found';
  end if;
  if v_case_status not in ('open','in_review','pending_information') then
    raise exception using errcode='55000', message='This verification case is already closed or decided';
  end if;
  if v_mode is distinct from 'registered_business' then
    raise exception using errcode='23514', message='Additional commercial verification information can only be requested from registered-business partner accounts';
  end if;

  update public.krim_partner_verification_cases
  set status='pending_information',
      decision=null,
      decision_reason=v_request,
      assigned_to=coalesce(assigned_to,v_user_id),
      started_at=coalesce(started_at,now()),
      completed_at=null,
      updated_at=now()
  where id=p_case_id;

  update public.krim_organizations
  set partner_verification_status='pending',
      partner_lifecycle_status='in_progress',
      partner_onboarding_status='needs_information',
      partner_reviewed_at=now(),
      partner_reviewed_by=v_user_id,
      partner_review_notes=v_request,
      updated_at=now()
  where id=v_org_id;

  v_new_state := jsonb_build_object(
    'case_status','pending_information',
    'decision',null,
    'organization_id',v_org_id,
    'request',v_request
  );

  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user_id,v_org_id,'partner.onboarding.information_requested','partner_verification_case',p_case_id::text,'partner_onboarding',
     jsonb_build_object('request',v_request),v_old_state,v_new_state);

  return jsonb_build_object(
    'case_id',p_case_id,
    'organization_id',v_org_id,
    'action','information_requested',
    'status','pending_information',
    'request',v_request
  );
end;
$function$;

revoke all on function public.krim_admin_request_partner_verification_information(bigint,text) from public, anon;
grant execute on function public.krim_admin_request_partner_verification_information(bigint,text) to authenticated;
