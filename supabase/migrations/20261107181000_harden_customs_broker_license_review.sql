-- Strengthen independent customs broker licence review.
-- Approval requires a current active customs organization/jurisdiction,
-- a meaningful reviewer rationale, and the original private evidence object.
create or replace function private.krim_customs_broker_license_review(p_license_id bigint,p_decision text,p_note text)
returns boolean language plpgsql security definer set search_path=public,storage,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_org bigint; v_country bigint; v_from date; v_until date; v_status text; v_path text; v_mime text; v_size bigint; v_submitter uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Multi-factor authentication required'; end if;
 if not private.krim_has_permission(v_user,1,'admin.platform') then raise exception 'Platform admin permission required'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'Invalid review decision'; end if;
 if length(trim(coalesce(p_note,'')))<20 then raise exception 'Independent verification note must contain at least 20 characters'; end if;
 select organization_id,country_id,valid_from,valid_until,status,evidence_path,evidence_mime_type,evidence_file_size,submitted_by
 into v_org,v_country,v_from,v_until,v_status,v_path,v_mime,v_size,v_submitter
 from public.krim_customs_broker_licenses where id=p_license_id for update;
 if v_org is null then raise exception 'License record not found'; end if;
 if v_status<>'pending_review' then raise exception 'License is not awaiting review'; end if;
 if not exists(select 1 from public.krim_organizations o where o.id=v_org and o.organization_type='customs' and o.status='active') then raise exception 'Customs broker organization is no longer active'; end if;
 if not exists(select 1 from public.krim_countries c where c.id=v_country and c.is_active) then raise exception 'Customs jurisdiction is no longer active'; end if;
 if p_decision='approved' then
  if v_from is not null and v_from>current_date then raise exception 'Future-effective licence cannot be approved before its effective date'; end if;
  if v_until is not null and v_until<current_date then raise exception 'Expired licence cannot be approved'; end if;
  if v_path is null or v_mime not in ('application/pdf','image/jpeg','image/png') or v_size is null or v_size<1 or v_size>10485760 then raise exception 'Valid licence evidence metadata is required for approval'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='krim-partner-verification' and o.name=v_path and o.owner=v_submitter and o.metadata->>'mimetype'=v_mime and (o.metadata->>'size')::bigint=v_size) then raise exception 'Original private licence evidence is missing or no longer matches the submitted metadata'; end if;
 end if;
 update public.krim_customs_broker_licenses set status=p_decision,reviewed_by=v_user,reviewed_at=now(),review_note=left(trim(p_note),2000),updated_at=now() where id=p_license_id;
 insert into public.krim_customs_broker_license_events(license_id,organization_id,event_type,actor_user_id,event_note)
 values(p_license_id,v_org,p_decision,v_user,left(trim(p_note),2000));
 return true;
end;$function$;
revoke all on function private.krim_customs_broker_license_review(bigint,text,text) from public,anon,authenticated;
grant execute on function private.krim_customs_broker_license_review(bigint,text,text) to authenticated;