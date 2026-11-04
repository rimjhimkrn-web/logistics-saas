-- Secure, expiring driver invitations tied to verified carrier organizations.
create or replace function public.krim_create_driver_invitation(p_email text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(btrim(coalesce(p_email,'')));v_org bigint;v_token text;v_id bigint;v_recent integer;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if v_email !~* '^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$' then raise exception using errcode='22023',message='Enter a valid driver email address';end if;
 select m.organization_id into v_org from public.krim_organization_members m
 where m.user_id=v_uid and m.status='active' and private.krim_has_permission(v_uid,m.organization_id,'partner.manage')
 order by m.created_at limit 1;
 if v_org is null then raise exception using errcode='42501',message='Active partner manager permission required';end if;
 if not exists(select 1 from public.krim_organizations o where o.id=v_org and o.status='active'
  and o.partner_account_mode='registered_business' and o.partner_verification_status='verified'
  and o.partner_lifecycle_status='active' and o.partner_compliance_status='compliant') then
  raise exception using errcode='42501',message='Verified compliant registered business required';end if;
 select count(*) into v_recent from public.krim_organization_invitations i
 where i.organization_id=v_org and i.role_code='driver' and i.created_at>now()-interval '1 hour';
 if v_recent>=10 then raise exception using errcode='42900',message='Driver invitation limit reached. Try again later.';end if;
 v_token:=gen_random_uuid()::text||gen_random_uuid()::text;
 insert into public.krim_organization_invitations(organization_id,email,role_code,invitation_token_hash,status,invited_by,expires_at)
 values(v_org,v_email,'driver',md5(v_token),'pending',v_uid,now()+interval '7 days') returning id into v_id;
 return jsonb_build_object('invitation_id',v_id,'email',v_email,'token',v_token,'expires_at',now()+interval '7 days');
end;$$;
revoke all on function public.krim_create_driver_invitation(text) from public,anon,authenticated;
grant execute on function public.krim_create_driver_invitation(text) to authenticated;

create or replace function public.krim_accept_driver_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v_inv public.krim_organization_invitations%rowtype;v_org public.krim_organizations%rowtype;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if p_token is null or length(p_token)<50 or length(p_token)>100 then raise exception using errcode='22023',message='Invalid driver invitation token';end if;
 select * into v_inv from public.krim_organization_invitations i where i.invitation_token_hash=md5(p_token) for update;
 if not found or v_inv.role_code<>'driver' or v_inv.status<>'pending' or v_inv.expires_at<=now() then
  raise exception using errcode='P0002',message='Driver invitation is invalid, expired or already used';end if;
 if v_email='' or v_email<>lower(v_inv.email) then raise exception using errcode='42501',message='Sign in with the email address that received this invitation';end if;
 select * into v_org from public.krim_organizations o where o.id=v_inv.organization_id for share;
 if v_org.status<>'active' or v_org.partner_account_mode<>'registered_business'
  or v_org.partner_verification_status<>'verified' or v_org.partner_lifecycle_status<>'active'
  or v_org.partner_compliance_status<>'compliant' then
  raise exception using errcode='42501',message='Inviting carrier organization is no longer eligible';end if;
 perform pg_advisory_xact_lock(hashtext('krim-driver-membership:'||v_inv.organization_id::text||':'||v_uid::text)::bigint);
 if exists(select 1 from public.krim_organization_members m where m.organization_id=v_inv.organization_id and m.user_id=v_uid
   and (m.role<>'driver' or m.status<>'active')) then
  raise exception using errcode='23514',message='This account already has a different membership in the carrier organization. Ask the organization administrator to resolve it.';
 end if;
 if not exists(select 1 from public.krim_organization_members m where m.organization_id=v_inv.organization_id and m.user_id=v_uid) then
  insert into public.krim_organization_members(organization_id,user_id,role,status) values(v_inv.organization_id,v_uid,'driver','active');
 end if;
 update public.krim_organization_invitations set status='accepted',accepted_at=now() where id=v_inv.id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_uid,v_inv.organization_id,'partner.driver_invitation.accepted','organization_invitation',v_inv.id::text,'driver_invitation',
 jsonb_build_object('email',v_email,'role','driver'));
 return jsonb_build_object('organization_id',v_inv.organization_id,'role','driver','status','active');
end;$$;
revoke all on function public.krim_accept_driver_invitation(text) from public,anon,authenticated;
grant execute on function public.krim_accept_driver_invitation(text) to authenticated;
