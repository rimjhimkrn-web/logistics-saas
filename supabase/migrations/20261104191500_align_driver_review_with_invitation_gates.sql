create or replace function private.krim_guard_driver_profile_verification()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_user uuid:=auth.uid();v_admin boolean:=v_user is not null and coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission(v_user,1::bigint,'admin.platform');v_invitation_accept boolean:=current_setting('krim.driver_invitation_accept',true)='on';v_valid_invitation boolean:=false;
begin
 if tg_op='INSERT' then
  if new.verification_status is distinct from 'pending' and not v_admin then raise exception using errcode='42501',message='New driver profiles must remain pending until administrator verification';end if;
  if (new.user_id is distinct from v_user or new.onboarding_mode not in ('standard','development_test')) and not v_admin then raise exception using errcode='42501',message='Driver profile identity and onboarding mode are not authorized';end if;
  return new;
 end if;
 if v_invitation_accept and v_user=new.user_id then
  select exists(select 1 from private.krim_driver_invitations i join auth.users u on lower(u.email)=i.invited_email join public.krim_organization_members m on m.organization_id=i.organization_id and m.user_id=u.id and m.role='driver' and m.status='active' where i.organization_id=new.organization_id and u.id=v_user and i.accepted_at is null and i.revoked_at is null and i.expires_at>now()) into v_valid_invitation;
 end if;
 if new.verification_status is distinct from old.verification_status and not v_admin and not (v_valid_invitation and new.verification_status='pending') then raise exception using errcode='42501',message='Driver verification status changes require administrator review or valid invitation acceptance';end if;
 if new.user_id is distinct from old.user_id and not v_admin then raise exception using errcode='42501',message='Driver identity cannot be changed';end if;
 if new.organization_id is distinct from old.organization_id and not v_admin and not v_valid_invitation then raise exception using errcode='42501',message='Driver organization changes require a valid carrier invitation';end if;
 return new;
end;
$$;
revoke all on function private.krim_guard_driver_profile_verification() from public,anon,authenticated;
create or replace function public.krim_admin_review_driver_document(p_document_id uuid,p_decision text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_user uuid:=auth.uid();v_decision text:=lower(nullif(btrim(p_decision),''));v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');v_doc public.krim_driver_verification_documents%rowtype;v_profile public.krim_driver_profiles%rowtype;v_verified boolean:=false;
begin
 if v_user is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception using errcode='42501',message='Multi-factor authentication required';end if;
 if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then raise exception using errcode='42501',message='Platform administrator permission required';end if;
 if p_document_id is null or v_decision not in ('accepted','rejected') then raise exception using errcode='22023',message='Select a document and accepted or rejected decision';end if;
 if v_decision='rejected' and char_length(coalesce(v_reason,''))<5 then raise exception using errcode='22023',message='A rejection reason of at least 5 characters is required';end if;
 if char_length(coalesce(v_reason,''))>1000 then raise exception using errcode='22023',message='Review reason is too long';end if;
 select * into v_doc from public.krim_driver_verification_documents where id=p_document_id for update;
 if not found then raise exception using errcode='P0002',message='Driver document not found';end if;
 if v_doc.review_status<>'pending' then raise exception using errcode='55000',message='Only pending driver documents can be reviewed';end if;
 select * into v_profile from public.krim_driver_profiles where id=v_doc.profile_id for update;
 if not found then raise exception using errcode='P0002',message='Driver profile not found';end if;
 update public.krim_driver_verification_documents set review_status=v_decision,review_reason=v_reason,reviewed_by=v_user,reviewed_at=now() where id=p_document_id;
 if v_decision='rejected' then update public.krim_driver_profiles set verification_status='rejected',updated_at=now() where id=v_profile.id;
 else
  select (nullif(btrim(v_profile.licence_number),'') is not null and bool_or(d.document_type='licence_front' and d.review_status='accepted') and bool_or(d.document_type='identity_document' and d.review_status='accepted')
   and exists(select 1 from public.krim_organizations o where o.id=v_profile.organization_id and o.status='active' and o.partner_account_mode='registered_business' and o.partner_verification_status='verified' and o.partner_lifecycle_status='active' and o.partner_compliance_status='compliant')
   and exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_profile.organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified')
   and exists(select 1 from public.krim_organization_members m where m.organization_id=v_profile.organization_id and m.user_id=v_profile.user_id and m.role='driver' and m.status='active')) into v_verified
  from public.krim_driver_verification_documents d where d.profile_id=v_profile.id;
  if coalesce(v_verified,false) then update public.krim_driver_profiles set verification_status='verified',updated_at=now() where id=v_profile.id;
  elsif v_profile.verification_status='rejected' then update public.krim_driver_profiles set verification_status='pending',updated_at=now() where id=v_profile.id;end if;
 end if;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,v_profile.organization_id,'driver.document.reviewed','driver_verification_document',p_document_id::text,'partner',jsonb_build_object('decision',v_decision,'reason',v_reason,'profile_id',v_profile.id),jsonb_build_object('review_status',v_doc.review_status,'profile_status',v_profile.verification_status),jsonb_build_object('review_status',v_decision,'profile_verified',coalesce(v_verified,false)));
 return jsonb_build_object('document_id',p_document_id,'decision',v_decision,'profile_id',v_profile.id,'profile_verified',coalesce(v_verified,false));
end;
$$;
revoke all on function public.krim_admin_review_driver_document(uuid,text,text) from public,anon;
grant execute on function public.krim_admin_review_driver_document(uuid,text,text) to authenticated;