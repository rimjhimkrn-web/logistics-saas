-- Require all three independently accepted driver identity/licence documents
-- before the driver profile can transition to verified.
alter policy krim_driver_docs_insert_own
on public.krim_driver_verification_documents
with check (
  user_id = (select auth.uid())
  and review_status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and storage_path ~ (
    '^' || (select auth.uid())::text || '/' || profile_id::text || '/[^/]+$'
  )
  and exists (
    select 1
    from storage.objects so
    where so.bucket_id = 'krim-driver-verification'
      and so.name = krim_driver_verification_documents.storage_path
      and so.owner = (select auth.uid())
  )
  and exists (
    select 1
    from public.krim_driver_profiles p
    where p.id = krim_driver_verification_documents.profile_id
      and p.user_id = (select auth.uid())
      and p.organization_id = krim_driver_verification_documents.organization_id
      and p.verification_status in ('pending','rejected')
  )
);

create or replace function public.krim_admin_review_driver_document(
  p_document_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_decision text := lower(nullif(btrim(p_decision),''));
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_doc public.krim_driver_verification_documents%rowtype;
  v_profile public.krim_driver_profiles%rowtype;
  v_verified boolean := false;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='Multi-factor authentication required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_document_id is null or v_decision not in ('accepted','rejected') then
    raise exception using errcode='22023', message='Select a document and accepted or rejected decision';
  end if;
  if v_decision='rejected' and char_length(coalesce(v_reason,''))<5 then
    raise exception using errcode='22023', message='A rejection reason of at least 5 characters is required';
  end if;
  if char_length(coalesce(v_reason,''))>1000 then
    raise exception using errcode='22023', message='Review reason is too long';
  end if;

  select * into v_doc
  from public.krim_driver_verification_documents
  where id=p_document_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Driver document not found';
  end if;
  if v_doc.review_status<>'pending' then
    raise exception using errcode='55000', message='Only pending driver documents can be reviewed';
  end if;
  if v_doc.user_id=v_user then
    raise exception using errcode='42501', message='A driver document submitter cannot review their own evidence';
  end if;
  if v_decision='accepted' and (
    v_doc.storage_path !~ ('^'||v_doc.user_id::text||'/'||v_doc.profile_id::text||'/[^/]+$')
    or not exists (
      select 1 from storage.objects so
      where so.bucket_id='krim-driver-verification'
        and so.name=v_doc.storage_path
        and so.owner=v_doc.user_id
    )
  ) then
    raise exception using errcode='23514', message='Cannot accept: the original driver evidence file is missing, outside its assigned private path, or not owned by the submitting driver';
  end if;

  select * into v_profile
  from public.krim_driver_profiles
  where id=v_doc.profile_id
  for update;
  if not found then
    raise exception using errcode='P0002', message='Driver profile not found';
  end if;

  update public.krim_driver_verification_documents
  set review_status=v_decision, review_reason=v_reason,
      reviewed_by=v_user, reviewed_at=now()
  where id=p_document_id;

  if v_decision='rejected' then
    update public.krim_driver_profiles
    set verification_status='rejected', updated_at=now()
    where id=v_profile.id;
  else
    select (
      nullif(btrim(v_profile.licence_number),'') is not null
      and bool_or(d.document_type='licence_front' and d.review_status='accepted')
      and bool_or(d.document_type='licence_back' and d.review_status='accepted')
      and bool_or(d.document_type='identity_document' and d.review_status='accepted')
      and exists (
        select 1 from public.krim_organizations o
        where o.id=v_profile.organization_id
          and o.status='active'
          and o.partner_account_mode='registered_business'
          and o.partner_verification_status='verified'
          and o.partner_lifecycle_status='active'
          and o.partner_compliance_status='compliant'
      )
      and exists (
        select 1 from public.krim_partner_capabilities c
        where c.organization_id=v_profile.organization_id
          and c.service_type='transport'
          and c.active=true
          and c.verification_status='verified'
      )
      and exists (
        select 1 from public.krim_organization_members m
        where m.organization_id=v_profile.organization_id
          and m.user_id=v_profile.user_id
          and m.role='driver'
          and m.status='active'
      )
    ) into v_verified
    from public.krim_driver_verification_documents d
    where d.profile_id=v_profile.id;

    if coalesce(v_verified,false) then
      update public.krim_driver_profiles
      set verification_status='verified', updated_at=now()
      where id=v_profile.id;
    elsif v_profile.verification_status='rejected' then
      update public.krim_driver_profiles
      set verification_status='pending', updated_at=now()
      where id=v_profile.id;
    end if;
  end if;

  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user,v_profile.organization_id,'driver.document.reviewed',
     'driver_verification_document',p_document_id::text,'partner',
     jsonb_build_object('decision',v_decision,'reason',v_reason,'profile_id',v_profile.id),
     jsonb_build_object('review_status',v_doc.review_status,'profile_status',v_profile.verification_status),
     jsonb_build_object('review_status',v_decision,'profile_verified',coalesce(v_verified,false)));

  return jsonb_build_object(
    'document_id',p_document_id,'decision',v_decision,
    'profile_id',v_profile.id,'profile_verified',coalesce(v_verified,false)
  );
end;
$function$;

revoke all on function public.krim_admin_review_driver_document(uuid,text,text) from public, anon;
grant execute on function public.krim_admin_review_driver_document(uuid,text,text) to authenticated, service_role;
