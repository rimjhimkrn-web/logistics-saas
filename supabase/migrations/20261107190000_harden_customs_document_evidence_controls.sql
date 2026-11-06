-- Tighten customs document uploads to the exact shipment party and accepted broker.
drop policy if exists "Customs shipment document upload scoped" on storage.objects;
create policy "Customs shipment document upload scoped" on storage.objects for insert to authenticated
with check (
 bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs-docs'
 and split_part(name,'/',2) ~ '^[0-9]+$' and split_part(name,'/',3) ~ '^[0-9]+$'
 and split_part(name,'/',4)=(select auth.uid())::text
 and exists(select 1 from public.krim_organization_members m where m.user_id=(select auth.uid()) and m.status='active'
  and m.organization_id=split_part(name,'/',3)::bigint
  and exists(select 1 from public.krim_shipments s join public.krim_shipment_customs c on c.shipment_id=s.id
   where s.id=split_part(name,'/',2)::bigint
    and ((s.customer_organization_id=m.organization_id and private.krim_has_permission((select auth.uid()),m.organization_id,'shipment.update'))
     or exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=c.id and a.shipment_id=s.id
      and a.broker_organization_id=m.organization_id and a.assignment_status='accepted'
      and private.krim_has_permission((select auth.uid()),m.organization_id,'compliance.view'))))
 )
);
drop policy if exists "Customs shipment document cleanup unregistered upload" on storage.objects;
create policy "Customs shipment document cleanup unregistered upload" on storage.objects for delete to authenticated
using (bucket_id='krim-partner-verification' and split_part(name,'/',1)='customs-docs'
 and split_part(name,'/',3) ~ '^[0-9]+$' and split_part(name,'/',4)=(select auth.uid())::text
 and owner=(select auth.uid())
 and exists(select 1 from public.krim_organization_members m where m.user_id=(select auth.uid()) and m.status='active' and m.organization_id=split_part(name,'/',3)::bigint)
 and not exists(select 1 from public.krim_customs_document_submissions d where d.storage_path=objects.name));

create or replace function private.krim_customs_document_submit(
 p_customs_record_id bigint,p_submitter_organization_id bigint,p_document_type text,p_document_reference text,
 p_issuing_country_id bigint,p_issued_at date,p_expires_at date,p_storage_path text,p_mime_type text,p_file_size bigint
) returns bigint language plpgsql security definer set search_path=public,storage,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_shipment bigint; v_id bigint; v_customer_org bigint; v_assigned boolean;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if p_document_type not in ('commercial_invoice','packing_list','certificate_of_origin','import_permit','export_permit','bill_of_lading','air_waybill','road_consignment_note','insurance_certificate','product_certificate','dangerous_goods_declaration','customs_declaration','duty_payment_receipt','inspection_certificate','other') then raise exception 'Unsupported customs document type'; end if;
 if p_mime_type not in ('application/pdf','image/jpeg','image/png') or p_file_size not between 1 and 10485760 then raise exception 'Evidence must be PDF/JPEG/PNG and no larger than 10 MB'; end if;
 if p_expires_at is not null and p_issued_at is not null and p_expires_at<p_issued_at then raise exception 'Invalid document validity dates'; end if;
 select shipment_id into v_shipment from public.krim_shipment_customs where id=p_customs_record_id;
 if v_shipment is null then raise exception 'Customs record not found'; end if;
 select customer_organization_id into v_customer_org from public.krim_shipments where id=v_shipment;
 if not exists(select 1 from public.krim_organization_members m where m.organization_id=p_submitter_organization_id and m.user_id=v_user and m.status='active') then raise exception 'Active submitter organization membership required'; end if;
 if p_submitter_organization_id=v_customer_org then
  if not private.krim_has_permission(v_user,p_submitter_organization_id,'shipment.update') then raise exception 'Customer shipment.update permission required'; end if;
 else
  select exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=p_customs_record_id and a.shipment_id=v_shipment and a.broker_organization_id=p_submitter_organization_id and a.assignment_status='accepted') into v_assigned;
  if not v_assigned or not private.krim_has_permission(v_user,p_submitter_organization_id,'compliance.view') then raise exception 'Accepted broker assignment and compliance permission required'; end if;
 end if;
 if p_issuing_country_id is not null and not exists(select 1 from public.krim_countries where id=p_issuing_country_id and is_active) then raise exception 'Issuing jurisdiction is inactive or unknown'; end if;
 if p_storage_path not like 'customs-docs/'||v_shipment::text||'/'||p_submitter_organization_id::text||'/'||v_user::text||'/%' then raise exception 'Invalid private document path'; end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='krim-partner-verification' and o.name=p_storage_path and o.owner=v_user and o.metadata->>'mimetype'=p_mime_type and (o.metadata->>'size')::bigint=p_file_size) then raise exception 'Uploaded private evidence not found or metadata mismatch'; end if;
 insert into public.krim_customs_document_submissions(customs_record_id,shipment_id,submitted_by_organization_id,submitted_by_user_id,document_type,document_reference,issuing_country_id,issued_at,expires_at,storage_path,mime_type,file_size)
 values(p_customs_record_id,v_shipment,p_submitter_organization_id,v_user,p_document_type,nullif(left(trim(coalesce(p_document_reference,'')),200),''),p_issuing_country_id,p_issued_at,p_expires_at,p_storage_path,p_mime_type,p_file_size) returning id into v_id;
 insert into public.krim_customs_document_events(submission_id,customs_record_id,shipment_id,event_type,actor_user_id,actor_organization_id,event_note)
 values(v_id,p_customs_record_id,v_shipment,'submitted',v_user,p_submitter_organization_id,'Document evidence submitted for review.');
 return v_id;
end;$function$;

create or replace function private.krim_customs_document_review(p_submission_id bigint,p_decision text,p_note text,p_actor_organization_id bigint)
returns boolean language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_record bigint; v_shipment bigint; v_submitter uuid; v_status text; v_broker bigint; v_customer bigint; v_is_admin boolean; v_actor_org bigint;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Multi-factor authentication required'; end if;
 if length(trim(coalesce(p_note,'')))<10 then raise exception 'A meaningful review note of at least 10 characters is required'; end if;
 select d.customs_record_id,d.shipment_id,d.submitted_by_user_id,d.status,s.customer_organization_id into v_record,v_shipment,v_submitter,v_status,v_customer
 from public.krim_customs_document_submissions d join public.krim_shipments s on s.id=d.shipment_id where d.id=p_submission_id for update of d;
 if v_record is null then raise exception 'Document submission not found'; end if;
 if v_submitter=v_user then raise exception 'Submitter cannot review their own document'; end if;
 if v_status<>'pending_review' then raise exception 'Document is not awaiting review'; end if;
 if p_decision not in ('verified','rejected') then raise exception 'Invalid document review decision'; end if;
 select a.broker_organization_id into v_broker from public.krim_customs_broker_assignments a where a.customs_record_id=v_record and a.shipment_id=v_shipment and a.assignment_status='accepted' order by a.accepted_at desc limit 1;
 v_is_admin:=coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission(v_user,1,'admin.platform');
 if p_actor_organization_id=v_broker and private.krim_has_permission(v_user,v_broker,'compliance.view') then v_actor_org:=v_broker;
 elsif p_decision='rejected' and p_actor_organization_id=v_customer and private.krim_has_permission(v_user,v_customer,'shipment.update') then v_actor_org:=v_customer;
 elsif p_decision='rejected' and v_is_admin then v_actor_org:=1;
 else raise exception 'Review requires the accepted broker, customer rejection authority, or AAL2 platform admin'; end if;
 update public.krim_customs_document_submissions set status=p_decision,reviewed_by=v_user,reviewed_by_organization_id=v_actor_org,reviewed_at=now(),review_note=left(trim(p_note),2000),updated_at=now() where id=p_submission_id;
 insert into public.krim_customs_document_events(submission_id,customs_record_id,shipment_id,event_type,actor_user_id,actor_organization_id,event_note)
 values(p_submission_id,v_record,v_shipment,p_decision,v_user,v_actor_org,left(trim(p_note),2000));
 return true;
end;$function$;
revoke all on function private.krim_customs_document_submit(bigint,bigint,text,text,bigint,date,date,text,text,bigint) from public,anon,authenticated;
grant execute on function private.krim_customs_document_submit(bigint,bigint,text,text,bigint,date,date,text,text,bigint) to authenticated;
revoke all on function private.krim_customs_document_review(bigint,text,text,bigint) from public,anon,authenticated;
grant execute on function private.krim_customs_document_review(bigint,text,text,bigint) to authenticated;
