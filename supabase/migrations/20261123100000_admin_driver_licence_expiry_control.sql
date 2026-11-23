-- Record driving-licence expiry through an independently authorized administrator workflow.
-- Drivers cannot self-approve or alter their verified licence evidence.
create or replace function public.krim_admin_update_driver_licence_expiry(
  p_profile_id uuid,
  p_licence_expiry_date date,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_profile public.krim_driver_profiles%rowtype;
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_previous date;
begin
  if v_user is null then
    raise exception using errcode='28000',message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501',message='Multi-factor authentication required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501',message='Platform administrator permission required';
  end if;
  if p_profile_id is null then
    raise exception using errcode='22023',message='Driver profile is required';
  end if;
  if char_length(coalesce(v_reason,'')) < 5 or char_length(v_reason) > 1000 then
    raise exception using errcode='22023',message='A reason between 5 and 1000 characters is required';
  end if;

  select * into v_profile
  from public.krim_driver_profiles
  where id=p_profile_id
  for update;

  if not found then
    raise exception using errcode='P0002',message='Driver profile not found';
  end if;
  if nullif(btrim(v_profile.licence_number),'') is null then
    raise exception using errcode='23514',message='A licence number must be recorded before its expiry date can be maintained';
  end if;

  v_previous := v_profile.licence_expiry_date;
  if v_previous is distinct from p_licence_expiry_date then
    update public.krim_driver_profiles
       set licence_expiry_date=p_licence_expiry_date,
           verification_status='pending',
           updated_at=now()
     where id=p_profile_id;

    -- The existing profile-change trigger reopens previously accepted licence
    -- evidence. Keep an additional explicit administrator audit event.
    insert into public.krim_audit_events(
      actor_user_id,organization_id,event_type,entity_type,entity_id,source,
      metadata,previous_state,new_state
    ) values (
      v_user,v_profile.organization_id,'driver.licence.expiry.updated',
      'driver_profile',p_profile_id::text,'platform_admin',
      jsonb_build_object('reason',v_reason,'re_review_required',true),
      jsonb_build_object('licence_expiry_date',v_previous,'verification_status',v_profile.verification_status),
      jsonb_build_object('licence_expiry_date',p_licence_expiry_date,'verification_status','pending')
    );
  end if;

  return jsonb_build_object(
    'profile_id',p_profile_id,
    'licence_expiry_date',p_licence_expiry_date,
    'changed',v_previous is distinct from p_licence_expiry_date,
    'verification_status',case when v_previous is distinct from p_licence_expiry_date then 'pending' else v_profile.verification_status end
  );
end;
$$;

revoke all on function public.krim_admin_update_driver_licence_expiry(uuid,date,text) from public,anon;
grant execute on function public.krim_admin_update_driver_licence_expiry(uuid,date,text) TO authenticated;
