alter table public.krim_driver_profiles
  add column if not exists licence_expiry_date date;

comment on column public.krim_driver_profiles.licence_expiry_date is
  'Expiry date transcribed from the original driving licence and independently checked by an authorized reviewer. Required for driver verification, vehicle binding, assignment acceptance and dispatch.';

do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.krim_admin_review_driver_document(uuid,text,text)'::regprocedure);
  v_old := $old$nullif(btrim(v_profile.licence_number),'') is not null
      and bool_or(d.document_type='licence_front' and d.review_status='accepted')$old$;
  v_new := $new$nullif(btrim(v_profile.licence_number),'') is not null
      and v_profile.licence_expiry_date is not null
      and v_profile.licence_expiry_date > current_date
      and bool_or(d.document_type='licence_front' and d.review_status='accepted')$new$;
  if position(v_old in v_def)=0 then raise exception 'Driver document review definition changed; aborting expiry migration'; end if;
  execute replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.krim_admin_review_driver_verification(uuid,text,text)'::regprocedure);
  v_old := $old$if coalesce(v_profile.licence_number,'')='' or char_length(coalesce(v_profile.full_name,''))<2 then raise exception using errcode='23514',message='Driver name and licence number are required';end if;$old$;
  v_new := $new$if coalesce(v_profile.licence_number,'')='' or char_length(coalesce(v_profile.full_name,''))<2 or v_profile.licence_expiry_date is null or v_profile.licence_expiry_date<=current_date then raise exception using errcode='23514',message='Driver name, licence number and a future verified licence expiry date are required';end if;$new$;
  if position(v_old in v_def)=0 then raise exception 'Driver profile review definition changed; aborting expiry migration'; end if;
  execute replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.krim_driver_accept_assignment(uuid)'::regprocedure);
  v_old := $old$dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL$old$;
  v_new := $new$dp.verification_status IN('verified','approved') AND nullif(btrim(dp.licence_number),'') IS NOT NULL AND dp.licence_expiry_date IS NOT NULL AND dp.licence_expiry_date>current_date$new$;
  if position(v_old in v_def)=0 then raise exception 'Driver assignment acceptance definition changed; aborting expiry migration'; end if;
  execute replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.krim_vehicle_driver_bind(bigint,uuid,uuid)'::regprocedure);
  v_old := $old$and dp.verification_status='verified' and nullif(btrim(dp.licence_number),'') is not null$old$;
  v_new := $new$and dp.verification_status='verified' and nullif(btrim(dp.licence_number),'') is not null and dp.licence_expiry_date is not null and dp.licence_expiry_date>current_date$new$;
  if position(v_old in v_def)=0 then raise exception 'Vehicle driver binding definition changed; aborting expiry migration'; end if;
  execute replace(v_def,v_old,v_new);

  v_def := pg_get_functiondef('public.krim_internal_dispatch_assigned_shipment(bigint)'::regprocedure);
  v_old := $old$AND dp.verification_status IN ('verified','approved')
      AND nullif(pg_catalog.btrim(dp.licence_number),'') IS NOT NULL$old$;
  v_new := $new$AND dp.verification_status IN ('verified','approved')
      AND nullif(pg_catalog.btrim(dp.licence_number),'') IS NOT NULL
      AND dp.licence_expiry_date IS NOT NULL
      AND dp.licence_expiry_date > current_date$new$;
  if position(v_old in v_def)=0 then raise exception 'Internal dispatch definition changed; aborting expiry migration'; end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
