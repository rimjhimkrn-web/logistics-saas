-- Queue a transactional email when an administrator requests partner verification information.
-- The outbox stores the user UUID, not a copied email address; the delivery worker must
-- resolve the current confirmed auth.users email at send time.
do $patch$
declare
  v_definition text;
  v_old_declaration text := $old$  v_recipient_user_id uuid;
  v_old_state jsonb;$old$;
  v_new_declaration text := $new$  v_recipient_user_id uuid;
  v_old_state jsonb;
  v_email_confirmed boolean := false;
  v_outbox_id bigint;
  v_old_block text := $old$  if v_recipient_user_id is not null
     and (v_case_status <> 'pending_information'
          or v_old_state->>'decision_reason' is distinct from v_request) then
    insert into public.notifications(user_id,title,message,notification_type,is_read)
    values(v_recipient_user_id,
      'Additional information required for your KRIM partner application',
      v_request,'alert',false);
  end if;
$old$;
  v_new_block text := $new$  if v_recipient_user_id is not null
     and (v_case_status <> 'pending_information'
          or v_old_state->>'decision_reason' is distinct from v_request) then
    insert into public.notifications(user_id,title,message,notification_type,is_read)
    values(v_recipient_user_id,
      'Additional information required for your KRIM partner application',
      v_request,'alert',false);

    select (u.email_confirmed_at is not null)
      into v_email_confirmed
    from auth.users u
    where u.id=v_recipient_user_id;

    if coalesce(v_email_confirmed,false)
       and not exists (
         select 1 from public.krim_notification_preferences pref
         where pref.user_id=v_recipient_user_id
           and pref.organization_id=v_org_id
           and pref.notification_type='partner_verification_information_requested'
           and pref.channel='email'
           and pref.enabled=false
       ) then
      with queued as (
        insert into public.krim_notification_outbox(
          organization_id,recipient_type,recipient_reference,notification_type,
          channel,priority,provider,subject,message,payload,status,
          scheduled_at,idempotency_key,metadata
        ) values (
          v_org_id,'user',v_recipient_user_id::text,
          'partner_verification_information_requested','email',10,'resend',
          'Action required: KRIM partner application',
          'KRIM needs additional information to review your partner application. Please sign in to your KRIM Partner Workspace and open Partner Onboarding to review the request and submit the missing information.',
          jsonb_build_object('template','partner_verification_information_requested',
            'case_id',p_case_id,'organization_id',v_org_id,
            'request',v_request,'workspace_path','/logistics-saas/app/partner/business/index.html'),
          'pending',now(),
          'partner-verification-info:'||p_case_id::text||':'||md5(v_request),
          jsonb_build_object('source','partner_verification_review','recipient_user_id',v_recipient_user_id)
        )
        on conflict (idempotency_key) where idempotency_key is not null do nothing
        returning id
      )
      select id into v_outbox_id from queued;

      if v_outbox_id is not null then
        insert into public.krim_notification_deliveries(
          outbox_id,channel,provider,status,next_attempt_at
        ) values(v_outbox_id,'email','resend','queued',now());
      end if;
    end if;
  end if;
$old$;
begin
  select pg_get_functiondef('public.krim_admin_request_partner_verification_information(bigint,text)'::regprocedure)
    into v_definition;
  if position(v_old_declaration in v_definition)=0
     or position(v_old_block in v_definition)=0 then
    raise exception 'Expected partner information-request notification block not found; refusing to patch';
  end if;
  v_definition:=replace(v_definition,v_old_declaration,v_new_declaration);
  v_definition:=replace(v_definition,v_old_block,v_new_block);
  execute v_definition;
end
$patch$;
