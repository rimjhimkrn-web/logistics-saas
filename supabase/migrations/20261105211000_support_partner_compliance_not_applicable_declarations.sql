alter table public.krim_partner_compliance_evidence
 alter column object_path drop not null,
 alter column file_name drop not null,
 alter column mime_type drop not null,
 alter column file_size drop not null;
alter table public.krim_partner_compliance_evidence
 add column if not exists submission_status text not null default 'uploaded'
  check (submission_status in ('uploaded','not_applicable')),
 add column if not exists partner_declaration text;

create or replace function public.krim_partner_submit_compliance_evidence(
 p_organization_id bigint,p_documents jsonb,p_declaration text
) returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
 u uuid:=auth.uid(); o public.krim_organizations%rowtype; v_country text;
 v_item jsonb; v_code text; v_path text; v_name text; v_mime text; v_size bigint;
 v_status text; v_reason text; v_seen text[]:=array[]::text[];
 v_required text[]:=array['business_registration','tax_registration','operating_authority','insurance_liability'];
 v_count integer:=0;
begin
 if u is null then raise exception using errcode='28000',message='Sign in is required'; end if;
 if p_organization_id is null or jsonb_typeof(p_documents) is distinct from 'array' or jsonb_array_length(p_documents)<>4 then
  raise exception using errcode='22023',message='Submit exactly four compliance evidence categories'; end if;
 if length(btrim(coalesce(p_declaration,'')))<30 or length(p_declaration)>2000 then
  raise exception using errcode='22023',message='A declaration of at least 30 characters is required'; end if;
 select * into o from public.krim_organizations where id=p_organization_id for share;
 if not found then raise exception using errcode='P0002',message='Partner organization not found'; end if;
 if o.status<>'active' or o.partner_account_mode<>'registered_business'
  or o.partner_verification_status<>'verified' or o.partner_lifecycle_status not in ('approved','active')
  or o.organization_type not in ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
  or not private.krim_has_permission(u,o.id,'partner.manage') then
  raise exception using errcode='42501',message='Only an authorized manager of an active, identity-verified registered business may submit compliance evidence'; end if;
 select coalesce(c.iso2_code,upper(c.code)) into v_country from public.krim_countries c where c.id=o.country_id;
 if v_country is null or v_country !~ '^[A-Z]{2}$' then
  raise exception using errcode='23514',message='A valid organization jurisdiction is required'; end if;
 for v_item in select value from jsonb_array_elements(p_documents) loop
  v_code:=v_item->>'check_code';v_status:=coalesce(v_item->>'submission_status','uploaded');
  v_path:=nullif(btrim(v_item->>'object_path'),'');v_name:=nullif(btrim(v_item->>'file_name'),'');
  v_mime:=v_item->>'mime_type';v_reason:=nullif(btrim(v_item->>'partner_declaration'),'');
  begin v_size:=nullif(v_item->>'file_size','')::bigint; exception when others then v_size:=null; end;
  if v_code is null or not(v_code=any(v_required)) or v_code=any(v_seen) then
   raise exception using errcode='22023',message='Unknown or duplicate compliance evidence category'; end if;
  v_seen:=array_append(v_seen,v_code);
  if v_status='uploaded' then
   if v_path is null or v_path !~ ('^'||o.id::text||'/'||u::text||'/compliance-'||v_code||'-[0-9a-fA-F-]{36}\\.(pdf|png|jpe?g)$') then
    raise exception using errcode='23514',message='Evidence path must use the organization, submitting user and category-specific file path'; end if;
   if v_name is null or length(v_name)>255 or v_mime not in ('application/pdf','image/jpeg','image/png')
    or v_size is null or v_size<1 or v_size>10485760 then
    raise exception using errcode='22023',message='Evidence must be a PDF, JPEG or PNG no larger than 10 MB'; end if;
   if not exists(select 1 from storage.objects so where so.bucket_id='krim-partner-verification'
    and so.name=v_path and so.owner=u and coalesce(so.metadata->>'mimetype','')=v_mime
    and coalesce(nullif(so.metadata->>'size','')::bigint,0)=v_size) then
    raise exception using errcode='23514',message='Uploaded evidence object, ownership, MIME type or size could not be verified'; end if;
  elsif v_status='not_applicable' then
   if v_path is not null or v_reason is null or length(v_reason)<20 or length(v_reason)>1000 then
    raise exception using errcode='22023',message='Not-applicable declarations require a 20 to 1000 character explanation and no file path'; end if;
   v_name:=null;v_mime:=null;v_size:=null;
  else raise exception using errcode='22023',message='Invalid partner evidence submission status'; end if;
 end loop;
 if cardinality(v_seen)<>4 then raise exception using errcode='22023',message='All four compliance categories are required'; end if;
 update public.krim_partner_compliance_evidence set is_current=false where organization_id=o.id and is_current=true;
 for v_item in select value from jsonb_array_elements(p_documents) loop
  insert into public.krim_partner_compliance_evidence
   (organization_id,check_code,object_path,file_name,mime_type,file_size,submitted_by,submission_status,partner_declaration)
  values(o.id,v_item->>'check_code',nullif(v_item->>'object_path',''),nullif(v_item->>'file_name',''),
   nullif(v_item->>'mime_type',''),nullif(v_item->>'file_size','')::bigint,u,
   coalesce(v_item->>'submission_status','uploaded'),nullif(v_item->>'partner_declaration',''));
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
DECLARE d text; old_snip text; new_snip text;
BEGIN
 SELECT pg_get_functiondef('public.krim_admin_list_partner_compliance_reviews()'::regprocedure) INTO d;
 old_snip := $old$'check_code',e.check_code,'object_path',e.object_path,'file_name',e.file_name,
       'mime_type',e.mime_type,'file_size',e.file_size,'submitted_at',e.submitted_at$old$;
 new_snip := $new$'check_code',e.check_code,'object_path',e.object_path,'file_name',e.file_name,
       'mime_type',e.mime_type,'file_size',e.file_size,'submitted_at',e.submitted_at,
       'submission_status',e.submission_status,'partner_declaration',e.partner_declaration$new$;
 IF position('submission_status' in d)=0 THEN
  IF position(old_snip in d)=0 THEN RAISE EXCEPTION 'Admin evidence JSON target not found'; END IF;
  d:=replace(d,old_snip,new_snip); EXECUTE d;
 END IF;
END $$;