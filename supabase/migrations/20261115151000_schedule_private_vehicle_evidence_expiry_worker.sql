create or replace function private.krim_internal_refresh_vehicle_expiry()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
 v_docs integer:=0;
 v_vehicles integer:=0;
begin
 with changed as (
  update public.krim_vehicle_documents d
  set review_status='expired',
      review_reason=coalesce(d.review_reason,'Evidence expiry date has passed.'),
      reviewed_at=now()
  where d.review_status='approved'
    and d.expires_at is not null
    and d.expires_at<current_date
  returning d.id,d.organization_id,d.expires_at
 )
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 select null,c.organization_id,'vehicle.document.expired','vehicle_document',c.id::text,
  'vehicle-expiry-monitor',
  jsonb_build_object('expires_at',c.expires_at,'actor','system:scheduled-expiry'),
  jsonb_build_object('review_status','expired')
 from changed c;
 get diagnostics v_docs=row_count;

 with changed as (
  update public.krim_vehicles v
  set verification_status='expired',
      operational_status='suspended',
      updated_at=now()
  where v.verification_status='verified'
   and exists (
    select 1 from public.krim_vehicle_document_requirements r
    where r.registration_country_code=v.registration_country_code
     and lower(r.vehicle_category)=lower(v.vehicle_category)
     and r.is_required=true
     and not exists (
      select 1 from public.krim_vehicle_documents d
      where d.vehicle_id=v.id
       and d.document_type=r.document_type
       and d.review_status='approved'
       and (d.expires_at is null or d.expires_at>=current_date)
     )
   )
  returning v.id,v.organization_id,v.verification_status,v.operational_status
 )
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,new_state)
 select null,c.organization_id,'vehicle.suspended_expired_evidence','vehicle',c.id::text,
  'vehicle-expiry-monitor',
  jsonb_build_object('reason','Mandatory evidence expired or is no longer valid','actor','system:scheduled-expiry'),
  jsonb_build_object('verification_status',c.verification_status,'operational_status',c.operational_status)
 from changed c;
 get diagnostics v_vehicles=row_count;

 return jsonb_build_object('expired_documents',v_docs,'suspended_vehicles',v_vehicles,'checked_at',now());
end;
$function$;

revoke all on function private.krim_internal_refresh_vehicle_expiry() from public,anon,authenticated,service_role;
grant execute on function private.krim_internal_refresh_vehicle_expiry() to postgres;

select cron.schedule(
 'krim-vehicle-evidence-expiry',
 '*/5 * * * *',
 'select private.krim_internal_refresh_vehicle_expiry();'
);