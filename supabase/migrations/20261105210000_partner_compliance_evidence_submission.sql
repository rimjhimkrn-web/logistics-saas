create table if not exists public.krim_partner_compliance_evidence (
 id bigint generated always as identity primary key,
 organization_id bigint not null references public.krim_organizations(id) on delete cascade,
 check_code text not null check (check_code in ('business_registration','tax_registration','operating_authority','insurance_liability')),
 object_path text not null,
 file_name text not null,
 mime_type text not null check (mime_type in ('application/pdf','image/jpeg','image/png')),
 file_size bigint not null check (file_size between 1 and 10485760),
 submitted_by uuid not null references auth.users(id),
 submitted_at timestamptz not null default now(),
 is_current boolean not null default true,
 constraint krim_partner_compliance_evidence_path_unique unique(object_path)
);
create index if not exists krim_partner_compliance_evidence_org_current_idx
 on public.krim_partner_compliance_evidence(organization_id,check_code,submitted_at desc)
 where is_current is true;
alter table public.krim_partner_compliance_evidence enable row level security;
alter table public.krim_partner_compliance_evidence force row level security;
revoke all on public.krim_partner_compliance_evidence from public,anon,authenticated;
revoke all on sequence public.krim_partner_compliance_evidence_id_seq from public,anon,authenticated;

create or replace function public.krim_partner_submit_compliance_evidence(
 p_organization_id bigint,
 p_documents jsonb,
 p_declaration text
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare
 u uuid:=auth.uid();
 o public.krim_organizations%rowtype;
 v_country text;
 v_item jsonb;
 v_code text;
 v_path text;
 v_name text;
 v_mime text;
 v_size bigint;
 v_seen text[]:=array[]::text[];
 v_required text[]:=array['business_registration','tax_registration','operating_authority','insurance_liability'];
 v_count integer:=0;
begin
 if u is null then raise exception using errcode='28000',message='Sign in is required'; end if;
 if p_organization_id is null or jsonb_typeof(p_documents) is distinct from 'array'
    or jsonb_array_length(p_documents)<>4 then
   raise exception using errcode='22023',message='Submit exactly four compliance evidence files'; end if;
 if length(btrim(coalesce(p_declaration,'')))<30 or length(p_declaration)>2000 then
   raise exception using errcode='22023',message='A declaration of at least 30 characters is required'; end if;
 select * into o from public.krim_organizations where id=p_organization_id for share;
 if not found then raise exception using errcode='P0002',message='Partner organization not found'; end if;
 if o.status<>'active' or o.partner_account_mode<>'registered_business'
    or o.partner_verification_status<>'verified'
    or o.partner_lifecycle_status not in ('approved','active')
    or o.organization_type not in ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
    or not private.krim_has_permission(u,o.id,'partner.manage') then
   raise exception using errcode='42501',message='Only an authorized manager of an active, identity-verified registered business may submit compliance evidence'; end if;
 select coalesce(c.iso2_code,upper(c.code)) into v_country
 from public.krim_countries c where c.id=o.country_id;
 if v_country is null or v_country !~ '^[A-Z]{2}$' then
   raise exception using errcode='23514',message='A valid organization jurisdiction is required'; end if;
 for v_item in select value from jsonb_array_elements(p_documents) loop
   v_code:=v_item->>'check_code';
   v_path:=nullif(btrim(v_item->>'object_path'),'');
   v_name:=nullif(btrim(v_item->>'file_name'),'');
   v_mime:=v_item->>'mime_type';
   begin v_size:=nullif(v_item->>'file_size','')::bigint;
   exception when others then v_size:=null; end;
   if v_code is null or not(v_code=any(v_required)) or v_code=any(v_seen) then
     raise exception using errcode='22023',message='Unknown or duplicate compliance evidence category'; end if;
   v_seen:=array_append(v_seen,v_code);
   if v_path is null or v_path !~ ('^'||o.id::text||'/'||u::text||'/compliance-'||v_code||'-[0-9a-fA-F-]{36}\\.(pdf|png|jpe?g)$') then
     raise exception using errcode='23514',message='Evidence path must use the organization, submitting user and category-specific file path'; end if;
   if v_name is null or length(v_name)>255 or v_mime not in ('application/pdf','image/jpeg','image/png')
      or v_size is null or v_size<1 or v_size>10485760 then
     raise exception using errcode='22023',message='Evidence must be a PDF, JPEG or PNG no larger than 10 MB'; end if;
   if not exists(
     select 1 from storage.objects so
     where so.bucket_id='krim-partner-verification' and so.name=v_path
       and so.owner=u and coalesce(so.metadata->>'mimetype','')=v_mime
       and coalesce(nullif(so.metadata->>'size','')::bigint,0)=v_size
   ) then
     raise exception using errcode='23514',message='Uploaded evidence object, ownership, MIME type or size could not be verified'; end if;
 end loop;
 if cardinality(v_seen)<>4 then raise exception using errcode='22023',message='All four compliance evidence categories are required'; end if;
 update public.krim_partner_compliance_evidence
 set is_current=false
 where organization_id=o.id and is_current=true;
 for v_item in select value from jsonb_array_elements(p_documents) loop
   insert into public.krim_partner_compliance_evidence
    (organization_id,check_code,object_path,file_name,mime_type,file_size,submitted_by)
   values(o.id,v_item->>'check_code',v_item->>'object_path',v_item->>'file_name',
     v_item->>'mime_type',(v_item->>'file_size')::bigint,u);
   v_count:=v_count+1;
 end loop;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 values(u,o.id,'partner.compliance.evidence_submitted','partner_compliance_evidence',o.id::text,'partner_compliance',
   jsonb_build_object('jurisdiction_code',v_country,'evidence_count',v_count,'declaration',btrim(p_declaration)),
   jsonb_build_object('status','submitted','check_codes',to_jsonb(v_required)));
 return jsonb_build_object('success',true,'organization_id',o.id,'jurisdiction_code',v_country,
   'evidence_count',v_count,'status','submitted','commercial_activation',false);
end
$function$;

revoke all on function public.krim_partner_submit_compliance_evidence(bigint,jsonb,text) from public,anon;
grant execute on function public.krim_partner_submit_compliance_evidence(bigint,jsonb,text) to authenticated;

DO $$
DECLARE d text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_list_partner_compliance_reviews()'::regprocedure) INTO d;
 IF position('compliance_evidence' in d)=0 THEN
  d:=replace(d,
   $old$'document_paths',coalesce(o.partner_metadata->'document_paths','[]'::jsonb),
   'latest_review',$old$,
   $new$'document_paths',coalesce(o.partner_metadata->'document_paths','[]'::jsonb),
   'compliance_evidence',(
     select coalesce(jsonb_agg(jsonb_build_object(
       'check_code',e.check_code,'object_path',e.object_path,'file_name',e.file_name,
       'mime_type',e.mime_type,'file_size',e.file_size,'submitted_at',e.submitted_at
     ) order by e.check_code),'[]'::jsonb)
     from public.krim_partner_compliance_evidence e
     where e.organization_id=o.id and e.is_current is true
   ),
   'latest_review',$new$);
  IF position('compliance_evidence' in d)=0 THEN RAISE EXCEPTION 'Could not extend compliance admin queue'; END IF;
  EXECUTE d;
 END IF;
END $$;