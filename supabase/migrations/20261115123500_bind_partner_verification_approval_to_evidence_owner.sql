create or replace function public.krim_admin_review_partner_verification(
  p_case_id bigint,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_case_status text;
  v_org_type text;
  v_org_status text;
  v_partner_metadata jsonb;
  v_submitter uuid;
  v_decision text := lower(nullif(btrim(p_decision),''));
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_old_state jsonb;
  v_new_state jsonb;
  v_document_paths text[];
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
  if p_case_id is null or v_decision is null or v_decision not in ('approved','rejected') then
    raise exception using errcode='22023', message='Choose an existing case and an approved or rejected decision';
  end if;
  if v_decision='rejected' and (v_reason is null or char_length(v_reason)<5) then
    raise exception using errcode='22023', message='A rejection reason of at least 5 characters is required';
  end if;
  if char_length(coalesce(v_reason,''))>1000 then
    raise exception using errcode='22023', message='Review notes must be 1000 characters or fewer';
  end if;

  select c.organization_id,c.status,
         jsonb_build_object('case_status',c.status,'decision',c.decision,
           'verification_status',o.partner_verification_status,'lifecycle_status',o.partner_lifecycle_status),
         coalesce(o.organization_type_code,o.organization_type),o.status,o.partner_metadata,
         nullif(o.partner_metadata->>'submitted_by','')::uuid
    into v_org_id,v_case_status,v_old_state,v_org_type,v_org_status,v_partner_metadata,v_submitter
  from public.krim_partner_verification_cases c
  join public.krim_organizations o on o.id=c.organization_id
  where c.id=p_case_id
  for update of c;

  if v_org_id is null then
    raise exception using errcode='P0002', message='Verification case not found';
  end if;
  if v_case_status not in ('open','in_review','pending_information') then
    raise exception using errcode='55000', message='This verification case has already been decided or closed';
  end if;

  if v_decision='approved' then
    if not exists (
      select 1 from public.krim_organizations o
      where o.id=v_org_id and o.partner_account_mode='registered_business'
    ) then
      raise exception using errcode='23514', message='Only a registered-business partner account can be approved for commercial access';
    end if;
    if lower(v_org_type) not in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator') or v_org_status <> 'active' then
      raise exception using errcode='23514', message='Only an active logistics organization can be approved';
    end if;
    if nullif(btrim(v_partner_metadata->>'authority_id'),'') is null
       or nullif(btrim(v_partner_metadata->>'country_code'),'') is null
       or nullif(btrim(v_partner_metadata->>'operating_country_code'),'') is null
       or nullif(btrim(v_partner_metadata->>'operational_category'),'') is null
       or nullif(btrim(v_partner_metadata->>'registered_address'),'') is null
       or nullif(btrim(v_partner_metadata->>'registered_city'),'') is null then
      raise exception using errcode='23514', message='Cannot approve: required business registration and location details are incomplete';
    end if;
    if jsonb_typeof(v_partner_metadata->'document_paths') is distinct from 'array'
       or jsonb_array_length(v_partner_metadata->'document_paths') < 1 then
      raise exception using errcode='23514', message='Cannot approve: a business registration document has not been submitted';
    end if;

    select array_agg(value) into v_document_paths
    from jsonb_array_elements_text(v_partner_metadata->'document_paths') as docs(value);

    if v_submitter is null or v_document_paths is null or cardinality(v_document_paths) < 1
       or exists (
         select 1 from unnest(v_document_paths) as submitted(path)
         where submitted.path !~ ('^' || v_org_id::text || '/' || v_submitter::text || '/[^/]+[.](pdf|png|jpe?g)$')
            or not exists (
              select 1 from storage.objects so
              where so.bucket_id='krim-partner-verification'
                and so.name=submitted.path
                and so.owner=v_submitter
            )
       ) then
      raise exception using errcode='23514', message='Cannot approve: submitted verification documents must exist in private storage and be owned by the original submitting user';
    end if;
  end if;

  update public.krim_partner_verification_cases
  set status=case when v_decision='approved' then 'approved' else 'rejected' end,
      decision=v_decision, decision_reason=v_reason,
      assigned_to=coalesce(assigned_to,v_user_id), started_at=coalesce(started_at,now()),
      completed_at=now(), updated_at=now()
  where id=p_case_id;

  if v_decision='approved' then
    update public.krim_organizations
    set partner_lifecycle_status='approved', partner_verification_status='verified',
        partner_compliance_status='pending', partner_onboarding_status='submitted',
        partner_verified_at=now(), partner_approved_at=now(), partner_reviewed_at=now(), partner_reviewed_by=v_user_id,
        partner_review_notes=v_reason, updated_at=now()
    where id=v_org_id;
  else
    update public.krim_organizations
    set partner_lifecycle_status='restricted', partner_verification_status='rejected',
        partner_compliance_status='non_compliant', partner_onboarding_status='blocked',
        partner_restricted_at=now(), partner_reviewed_at=now(), partner_reviewed_by=v_user_id,
        partner_review_notes=v_reason, updated_at=now()
    where id=v_org_id;
  end if;

  v_new_state := jsonb_build_object('case_status',case when v_decision='approved' then 'approved' else 'rejected' end,
    'decision',v_decision,'organization_id',v_org_id);
  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user_id,v_org_id,'partner.onboarding.reviewed','partner_verification_case',p_case_id::text,'partner_onboarding',
     jsonb_build_object('decision',v_decision,'reason',v_reason),v_old_state,v_new_state);

  return jsonb_build_object('case_id',p_case_id,'organization_id',v_org_id,'decision',v_decision,'status',v_new_state->>'case_status');
end;
$function$;
