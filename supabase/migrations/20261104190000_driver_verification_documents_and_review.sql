-- Private driver verification evidence and AAL2 administrator review.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('krim-driver-verification','krim-driver-verification',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;

create table if not exists public.krim_driver_verification_documents(
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.krim_driver_profiles(id) on delete cascade,
 user_id uuid not null,
 organization_id bigint not null references public.krim_organizations(id),
 document_type text not null check(document_type in ('licence_front','licence_back','identity_document')),
 storage_path text not null unique,
 original_file_name text not null,
 content_type text not null check(content_type in ('image/jpeg','image/png','image/webp','application/pdf')),
 file_size bigint not null check(file_size>0 and file_size<=10485760),
 review_status text not null default 'pending' check(review_status in ('pending','accepted','rejected')),
 review_reason text,reviewed_by uuid,reviewed_at timestamptz,created_at timestamptz not null default now(),
 constraint krim_driver_doc_path_owner check(storage_path like user_id::text||'/%')
);
create index if not exists krim_driver_verification_docs_profile_idx on public.krim_driver_verification_documents(profile_id,created_at desc);
alter table public.krim_driver_verification_documents enable row level security;
drop policy if exists krim_driver_docs_read_own on public.krim_driver_verification_documents;
create policy krim_driver_docs_read_own on public.krim_driver_verification_documents for select to authenticated using(user_id=auth.uid());
drop policy if exists krim_driver_docs_insert_own on public.krim_driver_verification_documents;
create policy krim_driver_docs_insert_own on public.krim_driver_verification_documents for insert to authenticated with check(
 user_id=auth.uid() and review_status='pending' and reviewed_by is null and reviewed_at is null
 and exists(select 1 from public.krim_driver_profiles p
   where p.id=public.krim_driver_verification_documents.profile_id
   and p.user_id=auth.uid()
   and p.organization_id=public.krim_driver_verification_documents.organization_id)
);
revoke all on public.krim_driver_verification_documents from anon,public;
grant select,insert on public.krim_driver_verification_documents to authenticated;

drop policy if exists krim_driver_verification_upload_own on storage.objects;
create policy krim_driver_verification_upload_own on storage.objects for insert to authenticated with check(
 bucket_id='krim-driver-verification' and (storage.foldername(name))[1]=auth.uid()::text
 and exists(select 1 from public.krim_driver_profiles p where p.user_id=auth.uid() and p.id::text=(storage.foldername(name))[2])
);
drop policy if exists krim_driver_verification_admin_read on storage.objects;
create policy krim_driver_verification_admin_read on storage.objects for select to authenticated using(
 bucket_id='krim-driver-verification' and coalesce(auth.jwt()->>'aal','aal1')='aal2'
 and private.krim_has_permission(auth.uid(),1::bigint,'admin.platform')
);

create or replace function public.krim_admin_list_driver_verification_cases()
returns table(profile_id uuid,user_id uuid,organization_id bigint,full_name text,country_code text,phone text,company_name text,licence_number text,verification_status text,created_at timestamptz,documents jsonb)
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' or not private.krim_has_permission(auth.uid(),1::bigint,'admin.platform') then
  raise exception using errcode='42501',message='AAL2 platform administrator permission required';end if;
 return query select p.id,p.user_id,p.organization_id,p.full_name,p.country_code,p.phone,p.company_name,p.licence_number,p.verification_status,p.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,'storage_path',d.storage_path,'file_name',d.original_file_name,'content_type',d.content_type,'file_size',d.file_size,'review_status',d.review_status,'created_at',d.created_at) order by d.created_at desc) from public.krim_driver_verification_documents d where d.profile_id=p.id),'[]'::jsonb)
 from public.krim_driver_profiles p where p.verification_status='pending' order by p.created_at asc;
end;$$;
revoke all on function public.krim_admin_list_driver_verification_cases() from public,anon,authenticated;
grant execute on function public.krim_admin_list_driver_verification_cases() to authenticated;

create or replace function public.krim_admin_review_driver_verification(p_profile_id uuid,p_decision text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_decision text:=lower(btrim(coalesce(p_decision,'')));v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
 v_profile public.krim_driver_profiles%rowtype;v_org public.krim_organizations%rowtype;v_doc_count integer;v_new text;
begin
 if v_uid is null then raise exception using errcode='28000',message='Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' or not private.krim_has_permission(v_uid,1::bigint,'admin.platform') then
  raise exception using errcode='42501',message='AAL2 platform administrator permission required';end if;
 if v_decision not in ('approved','rejected') then raise exception using errcode='22023',message='Decision must be approved or rejected';end if;
 if v_decision='rejected' and char_length(coalesce(v_reason,''))<5 then raise exception using errcode='22023',message='A rejection reason of at least 5 characters is required';end if;
 select * into v_profile from public.krim_driver_profiles where id=p_profile_id for update;
 if not found then raise exception using errcode='P0002',message='Driver profile not found';end if;
 if v_profile.verification_status<>'pending' then raise exception using errcode='55000',message='Only pending driver profiles can be reviewed';end if;
 select * into v_org from public.krim_organizations where id=v_profile.organization_id for share;
 if v_decision='approved' then
  if coalesce(v_profile.licence_number,'')='' or char_length(v_profile.full_name)<2 then raise exception using errcode='23514',message='Driver name and licence number are required';end if;
  select count(*) into v_doc_count from public.krim_driver_verification_documents d where d.profile_id=v_profile.id and d.review_status in ('pending','accepted');
  if v_doc_count=0 then raise exception using errcode='23514',message='At least one licence or identity document must be uploaded before approval';end if;
  if coalesce(v_org.partner_account_mode,'')<>'registered_business' or coalesce(v_org.status,'')<>'active'
   or coalesce(v_org.partner_verification_status,'')<>'verified' or coalesce(v_org.partner_lifecycle_status,'')<>'active'
   or coalesce(v_org.partner_compliance_status,'')<>'compliant' then
   raise exception using errcode='23514',message='Driver must belong to a verified, compliant registered carrier organization';end if;
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
