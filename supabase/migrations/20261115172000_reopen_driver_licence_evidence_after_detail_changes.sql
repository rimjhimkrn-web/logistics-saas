do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('private.krim_guard_driver_profile_verification()'::regprocedure);
  v_old := $old$if not v_admin and not v_valid_invitation and
   (new.licence_number is distinct from old.licence_number or new.licence_expiry_date is distinct from old.licence_expiry_date or new.full_name is distinct from old.full_name or new.country_code is distinct from old.country_code) then
  new.verification_status:='pending';
 end if;$old$;
  v_new := $new$if not v_admin and
   (new.licence_number is distinct from old.licence_number or new.licence_expiry_date is distinct from old.licence_expiry_date) then
  update public.krim_driver_verification_documents
     set review_status='pending',
         review_reason='Driver licence details changed; prior acceptance withdrawn pending independent re-review',
         reviewed_by=null,
         reviewed_at=null
   where profile_id=old.id
     and document_type in ('licence_front','licence_back')
     and review_status='accepted';
  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user,old.organization_id,'driver.licence.details.changed','driver_profile',old.id::text,
     'driver_profile_guard',
     jsonb_build_object('licence_number_changed',new.licence_number is distinct from old.licence_number,
                        'licence_expiry_changed',new.licence_expiry_date is distinct from old.licence_expiry_date,
                        'previously_accepted_licence_evidence_reopened',true),
     jsonb_build_object('verification_status',old.verification_status,'licence_expiry_date',old.licence_expiry_date),
     jsonb_build_object('verification_status','pending','licence_expiry_date',new.licence_expiry_date));
  new.verification_status:='pending';
 elsif not v_admin and not v_valid_invitation
   and (new.full_name is distinct from old.full_name or new.country_code is distinct from old.country_code) then
  new.verification_status:='pending';
 end if;$new$;
  if position(v_old in v_def)=0 then
    raise exception 'Driver profile guard definition changed; aborting evidence-reset migration';
  end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
