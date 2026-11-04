create or replace function public.krim_create_driver_invitation(p_organization_id bigint,p_email text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(btrim(coalesce(p_email,'')));v_token text;v_id uuid;v_org public.krim_organizations%rowtype;v_recent integer;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if not private.krim_has_permission(v_uid,p_organization_id,'partner.manage') then raise exception using errcode='42501',message='Partner management permission required';end if;
 if v_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then raise exception using errcode='22023',message='Enter a valid driver email address';end if;
 select * into v_org from public.krim_organizations where id=p_organization_id for share;
 if not found or coalesce(v_org.partner_account_mode,'')<>'registered_business' or coalesce(v_org.status,'')<>'active'
  or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
  or coalesce(v_org.partner_compliance_status,'')<>'compliant'
  or not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=p_organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified') then
  raise exception using errcode='23514',message='Only an eligible verified transport carrier can invite drivers';
 end if;
 select count(*) into v_recent from private.krim_driver_invitations where organization_id=p_organization_id and invited_by=v_uid and created_at>now()-interval '1 hour';
 if v_recent>=10 then raise exception using errcode='42900',message='Driver invitation limit reached. Try again later';end if;
 if exists(select 1 from auth.users u join public.krim_organization_members m on m.user_id=u.id
  where lower(u.email)=v_email and m.organization_id=p_organization_id and m.role='driver' and m.status='active') then
  raise exception using errcode='23505',message='This email already belongs to an active driver in your organization';
 end if;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 update private.krim_driver_invitations set revoked_at=now() where organization_id=p_organization_id and invited_email=v_email and accepted_at is null and revoked_at is null;
 insert into private.krim_driver_invitations(organization_id,invited_email,token_hash,invited_by,expires_at)
 values(p_organization_id,v_email,encode(extensions.digest(convert_to(v_token,'UTF8'),'sha256'),'hex'),v_uid,now()+interval '7 days') returning id into v_id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 values(v_uid,p_organization_id,'driver.invitation.created','driver_invitation',v_id::text,'driver_invitation',jsonb_build_object('email',v_email),jsonb_build_object('expires_at',now()+interval '7 days'));
 return jsonb_build_object('invitation_id',v_id,'email',v_email,'expires_at',now()+interval '7 days',
  'invite_url','https://rimjhimkrn-web.github.io/logistics-saas/auth/driver-signup.html?invite='||v_token);
end;$$;
revoke all on function public.krim_create_driver_invitation(bigint,text) from public,anon;
grant execute on function public.krim_create_driver_invitation(bigint,text) to authenticated;