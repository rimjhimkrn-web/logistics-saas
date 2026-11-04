-- Warehouse facility registration, controlled activation and movement eligibility.
alter table public.krim_warehouse_facilities
  add column if not exists review_status text not null default 'pending_review',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists reviewed_by uuid,
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_reason text;
alter table public.krim_warehouse_facilities drop constraint if exists krim_warehouse_facilities_review_status_check;
alter table public.krim_warehouse_facilities add constraint krim_warehouse_facilities_review_status_check check (review_status in ('pending_review','approved','rejected'));
create index if not exists krim_warehouse_facilities_review_queue_idx on public.krim_warehouse_facilities(review_status,created_at desc);

drop policy if exists krim_wh_facilities_org_member on public.krim_warehouse_facilities;
create policy krim_wh_facilities_org_member_select on public.krim_warehouse_facilities for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id
 where m.organization_id=krim_warehouse_facilities.organization_id and m.user_id=(select auth.uid()) and m.status='active'
 and lower(coalesce(o.status,''))='active'
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
 or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
 or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')));
revoke insert,update,delete on public.krim_warehouse_facilities from anon,authenticated;
grant select on public.krim_warehouse_facilities to authenticated;

create or replace function public.krim_warehouse_register_facility(p_organization_id bigint,p_facility_code text,p_facility_name text,p_country_code text,p_address_text text,p_timezone text,p_notes text default '')
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_facility public.krim_warehouse_facilities%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if p_organization_id is null then raise exception 'Organisation is required' using errcode='22023';end if;
 if nullif(btrim(p_facility_code),'') is null or length(btrim(p_facility_code))>40 or upper(btrim(p_facility_code)) !~ '^[A-Z0-9][A-Z0-9._-]{1,39}$' then raise exception 'Facility code must be 2–40 letters, numbers, dots, underscores or hyphens' using errcode='22023';end if;
 if nullif(btrim(p_facility_name),'') is null or length(btrim(p_facility_name))>180 then raise exception 'A valid facility name is required' using errcode='22023';end if;
 if upper(btrim(coalesce(p_country_code,''))) !~ '^[A-Z]{2}$' then raise exception 'Use a two-letter ISO country code' using errcode='22023';end if;
 if nullif(btrim(p_address_text),'') is null or length(btrim(p_address_text))>1000 then raise exception 'A facility address is required' using errcode='22023';end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=coalesce(nullif(btrim(p_timezone),''),'UTC')) then raise exception 'Select a valid IANA timezone' using errcode='22023';end if;
 if not exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
  where o.id=p_organization_id and m.user_id=v_user and m.status='active' and lower(coalesce(o.status,''))='active'
  and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved')
  and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
  and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%'
  or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%'
  or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%'))
 then raise exception 'An active, verified registered-business warehouse organisation membership is required' using errcode='42501';end if;
 if not private.krim_has_permission(v_user,p_organization_id,'partner.manage') then raise exception 'Facility management permission is required' using errcode='42501';end if;
 insert into public.krim_warehouse_facilities(organization_id,facility_code,facility_name,country_code,address_text,timezone,status,created_by,review_status,metadata)
 values(p_organization_id,upper(btrim(p_facility_code)),btrim(p_facility_name),upper(btrim(p_country_code)),btrim(p_address_text),
 coalesce(nullif(btrim(p_timezone),''),'UTC'),'inactive',v_user,'pending_review',
 jsonb_build_object('submission_notes',left(coalesce(p_notes,''),1000),'submitted_by',v_user,'submitted_at',now()))
 returning * into v_facility;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,p_organization_id,'warehouse.facility.submitted','warehouse_facility',v_facility.id::text,'rpc',
 jsonb_build_object('facility_code',v_facility.facility_code),null,jsonb_build_object('status',v_facility.status,'review_status',v_facility.review_status));
 return jsonb_build_object('facility_id',v_facility.id,'facility_code',v_facility.facility_code,'status',v_facility.status,
 'review_status',v_facility.review_status,'message','Facility submitted for administrator review. It is not operational until approved.');
end;$function$;

create or replace function public.krim_admin_list_warehouse_facilities()
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_items jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'AAL2 MFA is required' using errcode='42501';end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then raise exception 'Platform administrator permission required' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('facility_id',f.id,'organization_id',f.organization_id,'organization_name',o.legal_name,
 'organization_type',o.organization_type,'organization_type_code',o.organization_type_code,'organization_status',o.status,
 'partner_account_mode',o.partner_account_mode,'partner_verification_status',o.partner_verification_status,
 'partner_lifecycle_status',o.partner_lifecycle_status,'partner_compliance_status',o.partner_compliance_status,
 'facility_code',f.facility_code,'facility_name',f.facility_name,'country_code',f.country_code,'address_text',f.address_text,
 'timezone',f.timezone,'status',f.status,'review_status',f.review_status,'metadata',f.metadata,'created_at',f.created_at) order by f.created_at),'[]'::jsonb)
 into v_items from public.krim_warehouse_facilities f join public.krim_organizations o on o.id=f.organization_id where f.review_status='pending_review';
 return jsonb_build_object('items',v_items);
end;$function$;

create or replace function public.krim_admin_review_warehouse_facility(p_facility_id uuid,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare v_user uuid:=auth.uid();v_fac public.krim_warehouse_facilities%rowtype;v_org public.krim_organizations%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'AAL2 MFA is required' using errcode='42501';end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then raise exception 'Platform administrator permission required' using errcode='42501';end if;
 if p_facility_id is null or p_decision not in ('approved','rejected') then raise exception 'Invalid facility review decision' using errcode='22023';end if;
 if nullif(btrim(p_reason),'') is null or length(btrim(p_reason))<5 or length(btrim(p_reason))>1000 then raise exception 'Review reason must contain 5–1000 characters' using errcode='22023';end if;
 select * into v_fac from public.krim_warehouse_facilities where id=p_facility_id for update;
 if not found then raise exception 'Facility not found' using errcode='P0002';end if;
 if v_fac.review_status<>'pending_review' then raise exception 'Facility is no longer pending review' using errcode='55000';end if;
 select * into v_org from public.krim_organizations where id=v_fac.organization_id for update;
 if p_decision='approved' and not (lower(coalesce(v_org.status,''))='active' and v_org.partner_account_mode='registered_business'
 and v_org.partner_verification_status in ('verified','approved') and v_org.partner_lifecycle_status in ('active','verified')
 and v_org.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (v_org.organization_type ilike '%warehouse%' or v_org.organization_type_code ilike '%warehouse%'
 or v_org.organization_type ilike '%fulfilment%' or v_org.organization_type_code ilike '%fulfilment%'
 or v_org.organization_type ilike '%fulfillment%' or v_org.organization_type_code ilike '%fulfillment%'))
 then raise exception 'Organisation is not eligible for facility approval' using errcode='42501';end if;
 update public.krim_warehouse_facilities set status=case when p_decision='approved' then 'active' else 'inactive' end,
 review_status=p_decision,reviewed_by=v_user,reviewed_at=now(),review_reason=btrim(p_reason),
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('reviewed_by',v_user,'reviewed_at',now(),'decision',p_decision,'decision_reason',btrim(p_reason))
 where id=p_facility_id returning * into v_fac;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,v_fac.organization_id,'warehouse.facility.reviewed','warehouse_facility',v_fac.id::text,'rpc',
 jsonb_build_object('decision',p_decision,'reason',btrim(p_reason)),jsonb_build_object('status','inactive','review_status','pending_review'),
 jsonb_build_object('status',v_fac.status,'review_status',v_fac.review_status));
 return jsonb_build_object('facility_id',v_fac.id,'decision',p_decision,'status',v_fac.status,'review_status',v_fac.review_status);
end;$function$;

revoke all on function public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text) to authenticated;
revoke all on function public.krim_admin_list_warehouse_facilities() from public,anon,authenticated;
grant execute on function public.krim_admin_list_warehouse_facilities() to authenticated;
revoke all on function public.krim_admin_review_warehouse_facility(uuid,text,text) from public,anon,authenticated;
grant execute on function public.krim_admin_review_warehouse_facility(uuid,text,text) to authenticated;

do $patch$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure) into v_def;
 v_old:='if v_org_type is null then raise exception ''Active warehouse organization membership required'' using errcode=''42501''; end if;';
 v_new:='if v_org_type is null or not exists(select 1 from public.krim_organizations o where o.id=p_organization_id and o.partner_account_mode=''registered_business'' and o.partner_verification_status in (''verified'',''approved'') and o.partner_lifecycle_status in (''active'',''verified'') and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')) then raise exception ''Verified registered-business warehouse organisation required'' using errcode=''42501''; end if;';
 if position(v_old in v_def)=0 then raise exception 'Could not locate warehouse movement authorization guard';end if;
 execute replace(v_def,v_old,v_new);
end;$patch$;
