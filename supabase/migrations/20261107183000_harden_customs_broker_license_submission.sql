-- Customs broker licence submission authorization and duplicate control.
create unique index if not exists krim_customs_broker_license_active_number_unique
on public.krim_customs_broker_licenses(organization_id,country_id,lower(trim(license_number)))
where status in ('pending_review','approved');

create or replace function private.krim_customs_broker_license_submit(
 p_organization_id bigint,p_country_id bigint,p_authority_name text,p_license_number text,p_license_type text,
 p_valid_from date,p_valid_until date,p_evidence_path text,p_evidence_mime text,p_evidence_size bigint
) returns bigint language plpgsql security definer set search_path=public,storage,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_license_id bigint;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if length(trim(coalesce(p_authority_name,'')))<2 then raise exception 'Issuing authority is required'; end if;
 if length(trim(coalesce(p_license_number,'')))<2 then raise exception 'Licence number is required'; end if;
 if length(trim(coalesce(p_license_type,'')))<2 then raise exception 'Licence type is required'; end if;
 if p_valid_until is not null and p_valid_from is not null and p_valid_until<p_valid_from then raise exception 'Invalid licence validity dates'; end if;
 if p_evidence_size is null or p_evidence_size<1 or p_evidence_size>10485760 then raise exception 'Evidence must be between 1 byte and 10 MB'; end if;
 if p_evidence_mime not in ('application/pdf','image/jpeg','image/png') then raise exception 'Unsupported evidence file type'; end if;
 if not exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
  where o.id=p_organization_id and o.status='active' and o.organization_type='customs' and m.user_id=v_user and m.status='active'
   and private.krim_has_permission(v_user,p_organization_id,'compliance.manage')) then
  raise exception 'Active customs organization membership and compliance.manage permission required';
 end if;
 if not exists(select 1 from public.krim_countries c where c.id=p_country_id and c.is_active) then raise exception 'Active jurisdiction required'; end if;
 if p_evidence_path not like 'customs/'||p_organization_id::text||'/'||v_user::text||'/%' then raise exception 'Invalid evidence storage path'; end if;
 if not exists(select 1 from storage.objects where bucket_id='krim-partner-verification' and name=p_evidence_path and owner=v_user
  and metadata->>'mimetype'=p_evidence_mime and (metadata->>'size')::bigint=p_evidence_size) then
  raise exception 'Evidence upload not found or does not match the submitted file details';
 end if;
 insert into public.krim_customs_broker_licenses(organization_id,country_id,authority_name,license_number,license_type,valid_from,valid_until,evidence_path,evidence_mime_type,evidence_file_size,submitted_by)
 values(p_organization_id,p_country_id,left(trim(p_authority_name),200),left(trim(p_license_number),100),left(trim(p_license_type),100),p_valid_from,p_valid_until,p_evidence_path,p_evidence_mime,p_evidence_size,v_user)
 returning id into v_license_id;
 insert into public.krim_customs_broker_license_events(license_id,organization_id,event_type,actor_user_id,event_note)
 values(v_license_id,p_organization_id,'submitted',v_user,'Licence evidence submitted for independent review.');
 return v_license_id;
end;$function$;
revoke all on function private.krim_customs_broker_license_submit(bigint,bigint,text,text,text,date,date,text,text,bigint) from public,anon,authenticated;
grant execute on function private.krim_customs_broker_license_submit(bigint,bigint,text,text,text,date,date,text,text,bigint) to authenticated;
