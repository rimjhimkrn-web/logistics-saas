create or replace function public.krim_vehicle_review_document(p_document_id uuid,p_decision text,p_reason text default null)
returns text language plpgsql security definer set search_path to '' as $function$
declare
 v_user uuid:=public.krim_vehicle_admin_guard();
 v_doc public.krim_vehicle_documents%rowtype;
 v_object_mime text;
 v_object_size bigint;
begin
 if p_decision not in('approved','rejected') then raise exception using errcode='22023',message='Decision must be approved or rejected';end if;
 if p_decision='rejected' and length(btrim(coalesce(p_reason,'')))<5 then raise exception using errcode='22023',message='A clear rejection reason is required';end if;
 if length(coalesce(p_reason,''))>1000 then raise exception using errcode='22023',message='Review reason is too long';end if;
 select * into v_doc from public.krim_vehicle_documents where id=p_document_id for update;
 if not found then raise exception using errcode='P0002',message='Vehicle document not found';end if;
 if v_doc.created_by=v_user then raise exception using errcode='42501',message='A reviewer cannot approve or reject their own submission';end if;
 if v_doc.review_status in('approved','rejected','expired') then raise exception using errcode='55000',message='This document has already received a final decision';end if;
 if p_decision='approved' then
  if v_doc.expires_at is not null and v_doc.expires_at<current_date then
   raise exception using errcode='23514',message='Expired evidence cannot be approved';
  end if;
  if v_doc.storage_path !~ ('^'||v_doc.organization_id::text||'/'||v_doc.created_by::text||'/vehicle/'||v_doc.vehicle_id::text||'/[A-Za-z0-9._-]+$') then
   raise exception using errcode='23514',message='Vehicle evidence path is outside the registered private location';
  end if;
  select o.metadata->>'mimetype',nullif(o.metadata->>'size','')::bigint
   into v_object_mime,v_object_size
  from storage.objects o
  where o.bucket_id='krim-partner-verification'
    and o.name=v_doc.storage_path
    and o.owner_id=v_doc.created_by::text;
  if not found then raise exception using errcode='23503',message='Vehicle evidence file is missing or is not owned by its original uploader';end if;
  if v_object_mime is distinct from v_doc.content_type or v_object_size is distinct from v_doc.file_size then
   raise exception using errcode='23514',message='Stored vehicle evidence metadata does not match its registered document record';
  end if;
 end if;
 update public.krim_vehicle_documents
 set review_status=p_decision,review_reason=nullif(btrim(p_reason),''),reviewed_by=v_user,reviewed_at=now()
 where id=p_document_id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,v_doc.organization_id,'vehicle.document.reviewed','vehicle_document',v_doc.id::text,'vehicle-verification-console',
  jsonb_build_object('decision',p_decision,'reason',nullif(btrim(p_reason),''),'evidence_owner_verified',p_decision='approved'),
  jsonb_build_object('review_status',v_doc.review_status),
  jsonb_build_object('review_status',p_decision,'reviewed_at',now()));
 return p_decision;
end;$function$;
revoke all on function public.krim_vehicle_review_document(uuid,text,text) from public,anon;
grant execute on function public.krim_vehicle_review_document(uuid,text,text) to authenticated,service_role;
