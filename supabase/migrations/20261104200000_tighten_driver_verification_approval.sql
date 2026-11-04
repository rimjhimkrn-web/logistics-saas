create or replace function public.krim_admin_review_driver_verification(p_profile_id uuid,p_decision text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_decision text:=lower(btrim(coalesce(p_decision,'')));v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_profile public.krim_driver_profiles%rowtype;v_org public.krim_organizations%rowtype;v_doc_count integer;v_new text;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' or not private.krim_has_permission(v_uid,1::bigint,'admin.platform') then raise exception using errcode='42501',message='AAL2 platform administrator permission required';end if;
 if v_decision not in ('approved','rejected') then raise exception using errcode='22023',message='Decision must be approved or rejected';end if;
 if v_decision='rejected' and char_length(coalesce(v_reason,''))<5 then raise exception using errcode='22023',message='A rejection reason of at least 5 characters is required';end if;
 select * into v_profile from public.krim_driver_profiles where id=p_profile_id for update;
 if not found then raise exception using errcode='P0002',message='Driver profile not found';end if;
 if v_profile.verification_status<>'pending' then raise exception using errcode='55000',message='Only pending driver profiles can be reviewed';end if;
 select * into v_org from public.krim_organizations where id=v_profile.organization_id for share;
 if v_decision='approved' then
  if coalesce(v_profile.licence_number,'')='' or char_length(v_profile.full_name)<2 then raise exception using errcode='23514',message='Driver name and licence number are required';end if;
  if not exists(select 1 from public.krim_organization_members m where m.organization_id=v_profile.organization_id and m.user_id=v_profile.user_id and m.role='driver' and m.status='active') then raise exception using errcode='23514',message='An active driver membership in the carrier organization is required';end if;
  if not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_profile.organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified') then raise exception using errcode='23514',message='Carrier transport capability must be independently verified';end if;
  select count(*) into v_doc_count from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type in ('licence_front','licence_back') and d.review_status='pending';
  if v_doc_count=0 then raise exception using errcode='23514',message='A pending driving-licence document must be uploaded before approval';end if;
  if coalesce(v_org.partner_account_mode,'')<>'registered_business' or coalesce(v_org.status,'')<>'active'
   or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
   or coalesce(v_org.partner_compliance_status,'')<>'compliant' then raise exception using errcode='23514',message='Driver must belong to a verified, compliant registered carrier organization';end if;
 end if;
 v_new:=case when v_decision='approved' then 'verified' else 'rejected' end;
 update public.krim_driver_profiles set verification_status=v_new,updated_at=now() where id=p_profile_id;
 update public.krim_driver_verification_documents set review_status=case when v_decision='approved' then 'accepted' else 'rejected' end,review_reason=v_reason,reviewed_by=v_uid,reviewed_at=now() where profile_id=p_profile_id and review_status='pending';
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_uid,v_profile.organization_id,'driver.profile.reviewed','driver_profile',p_profile_id::text,'driver_verification_review',
 jsonb_build_object('decision',v_decision,'reason',v_reason),jsonb_build_object('verification_status',v_profile.verification_status),
 jsonb_build_object('verification_status',v_new,'document_count',v_doc_count));
 return jsonb_build_object('profile_id',p_profile_id,'decision',v_decision,'verification_status',v_new);
end;$$;
revoke all on function public.krim_admin_review_driver_verification(uuid,text,text) from public,anon,authenticated;
grant execute on function public.krim_admin_review_driver_verification(uuid,text,text) to authenticated;