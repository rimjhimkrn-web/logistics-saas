CREATE OR REPLACE FUNCTION public.krim_admin_review_driver_document(p_document_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_user uuid:=auth.uid();
 v_decision text:=lower(nullif(btrim(p_decision),''));
 v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_doc public.krim_driver_verification_documents%rowtype;
 v_profile public.krim_driver_profiles%rowtype;
 v_verified boolean:=false;
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
 if v_doc.user_id=v_user then raise exception using errcode='42501',message='A driver document submitter cannot review their own evidence';end if;
 if v_decision='accepted' and (
  v_doc.storage_path !~ ('^'||v_doc.user_id::text||'/'||v_doc.profile_id::text||'/[^/]+$')
  or not exists(select 1 from storage.objects so where so.bucket_id='krim-driver-verification' and so.name=v_doc.storage_path and so.owner=v_doc.user_id)
 ) then raise exception using errcode='23514',message='Cannot accept: the original driver evidence file is missing, outside its assigned private path, or not owned by the submitting driver';end if;
 select * into v_profile from public.krim_driver_profiles where id=v_doc.profile_id for update;
 if not found then raise exception using errcode='P0002',message='Driver profile not found';end if;
 update public.krim_driver_verification_documents set review_status=v_decision,review_reason=v_reason,reviewed_by=v_user,reviewed_at=now() where id=p_document_id;
 if v_decision='rejected' then
  update public.krim_driver_profiles set verification_status='rejected',updated_at=now() where id=v_profile.id;
 else
  select (
   nullif(btrim(v_profile.licence_number),'') is not null
   and bool_or(d.document_type='licence_front' and d.review_status='accepted')
   and bool_or(d.document_type='licence_back' and d.review_status='accepted')
   and bool_or(d.document_type='identity_document' and d.review_status='accepted')
   and exists(select 1 from public.krim_organizations o where o.id=v_profile.organization_id and o.status='active' and o.partner_account_mode='registered_business' and o.partner_verification_status='verified' and o.partner_lifecycle_status='active' and o.partner_compliance_status='compliant')
   and exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_profile.organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified' and (c.effective_from is null or c.effective_from<=current_date) and (c.effective_until is null or c.effective_until>=current_date))
   and exists(select 1 from public.krim_organization_members m where m.organization_id=v_profile.organization_id and m.user_id=v_profile.user_id and m.role='driver' and m.status='active')
  ) into v_verified from public.krim_driver_verification_documents d where d.profile_id=v_profile.id;
  if coalesce(v_verified,false) then
   update public.krim_driver_profiles set verification_status='verified',updated_at=now() where id=v_profile.id;
  elsif v_profile.verification_status='rejected' then
   update public.krim_driver_profiles set verification_status='pending',updated_at=now() where id=v_profile.id;
  end if;
 end if;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,v_profile.organization_id,'driver.document.reviewed','driver_verification_document',p_document_id::text,'partner',
  jsonb_build_object('decision',v_decision,'reason',v_reason,'profile_id',v_profile.id,'requires_front_back_licence_and_identity',true),
  jsonb_build_object('review_status',v_doc.review_status,'profile_status',v_profile.verification_status),
  jsonb_build_object('review_status',v_decision,'profile_verified',coalesce(v_verified,false)));
 return jsonb_build_object('document_id',p_document_id,'decision',v_decision,'profile_id',v_profile.id,'profile_verified',coalesce(v_verified,false));
end;$function$

revoke all on function public.krim_admin_review_driver_document(uuid,text,text) from public,anon;
grant execute on function public.krim_admin_review_driver_document(uuid,text,text) to authenticated,service_role;

CREATE OR REPLACE FUNCTION public.krim_admin_review_driver_verification(p_profile_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_uid uuid:=auth.uid();
 v_decision text:=lower(btrim(coalesce(p_decision,'')));
 v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_profile public.krim_driver_profiles%rowtype;
 v_org public.krim_organizations%rowtype;
 v_new text;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' or not private.krim_has_permission(v_uid,1::bigint,'admin.platform') then raise exception using errcode='42501',message='AAL2 platform administrator permission required';end if;
 if v_decision not in('approved','rejected') then raise exception using errcode='22023',message='Decision must be approved or rejected';end if;
 if v_decision='rejected' and char_length(coalesce(v_reason,''))<5 then raise exception using errcode='22023',message='A rejection reason of at least 5 characters is required';end if;
 if char_length(coalesce(v_reason,''))>1000 then raise exception using errcode='22023',message='Review reason is too long';end if;
 select * into v_profile from public.krim_driver_profiles where id=p_profile_id for update;
 if not found then raise exception using errcode='P0002',message='Driver profile not found';end if;
 if v_profile.verification_status<>'pending' then raise exception using errcode='55000',message='Only pending driver profiles can be reviewed';end if;
 if v_profile.user_id=v_uid then raise exception using errcode='42501',message='A driver cannot review their own driver profile';end if;
 select * into v_org from public.krim_organizations where id=v_profile.organization_id for share;
 if v_decision='approved' then
  if coalesce(v_profile.licence_number,'')='' or char_length(coalesce(v_profile.full_name,''))<2 then raise exception using errcode='23514',message='Driver name and licence number are required';end if;
  if not exists(select 1 from public.krim_organization_members m where m.organization_id=v_profile.organization_id and m.user_id=v_profile.user_id and m.role='driver' and m.status='active') then raise exception using errcode='23514',message='An active driver membership in the carrier organization is required';end if;
  if not exists(select 1 from public.krim_partner_capabilities c where c.organization_id=v_profile.organization_id and c.service_type='transport' and c.active=true and c.verification_status='verified' and (c.effective_from is null or c.effective_from<=current_date) and (c.effective_until is null or c.effective_until>=current_date)) then raise exception using errcode='23514',message='A current independently verified transport capability is required';end if;
  if coalesce(v_org.partner_account_mode,'')<>'registered_business' or coalesce(v_org.status,'')<>'active' or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active' or coalesce(v_org.partner_compliance_status,'')<>'compliant' then raise exception using errcode='23514',message='Driver must belong to a verified, compliant registered carrier organization';end if;
  if not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='licence_front' and d.review_status='accepted')
   or not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='licence_back' and d.review_status='accepted')
   or not exists(select 1 from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.document_type='identity_document' and d.review_status='accepted') then
   raise exception using errcode='23514',message='Front and back driving licence and identity documents must be independently reviewed and accepted before profile approval';
  end if;
 end if;
 v_new:=case when v_decision='approved' then 'verified' else 'rejected' end;
 update public.krim_driver_profiles set verification_status=v_new,updated_at=now() where id=p_profile_id;
 if v_decision='rejected' then update public.krim_driver_verification_documents set review_status='rejected',review_reason=v_reason,reviewed_by=v_uid,reviewed_at=now() where profile_id=p_profile_id and review_status='pending';end if;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_uid,v_profile.organization_id,'driver.profile.reviewed','driver_profile',p_profile_id::text,'driver_verification_review',jsonb_build_object('decision',v_decision,'reason',v_reason),jsonb_build_object('verification_status',v_profile.verification_status),jsonb_build_object('verification_status',v_new,'document_acceptance_required',v_decision='approved'));
 return jsonb_build_object('profile_id',p_profile_id,'decision',v_decision,'verification_status',v_new);
end;$function$

revoke all on function public.krim_admin_review_driver_verification(uuid,text,text) from public,anon;
grant execute on function public.krim_admin_review_driver_verification(uuid,text,text) to authenticated,service_role;
