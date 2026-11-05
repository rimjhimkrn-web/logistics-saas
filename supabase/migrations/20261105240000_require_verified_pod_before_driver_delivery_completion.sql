-- Driver milestone API must not mark a trip delivered before platform POD verification.
-- POD submission and delivery authorization are separate controlled workflows.
create or replace function public.krim_driver_record_trip_event(
  p_assignment_id uuid,
  p_event_type text,
  p_notes text default ''
)
returns public.krim_driver_assignments
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user uuid := auth.uid();
  v_assignment public.krim_driver_assignments;
  v_next_status text;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;

  if p_event_type not in ('pickup','in_transit','exception') then
    raise exception using errcode='22023',
      message='Unsupported trip event. Delivery completion is recorded only after authorized POD verification.';
  end if;

  if p_event_type='exception' and length(btrim(coalesce(p_notes,'')))<3 then
    raise exception using errcode='22023',message='Please provide details for an exception';
  end if;

  select a.* into v_assignment
  from public.krim_driver_assignments a
  where a.id=p_assignment_id
    and a.user_id=v_user
    and exists(
      select 1
      from public.krim_organization_members m
      where m.user_id=v_user
        and m.organization_id=a.organization_id
        and lower(m.role)='driver'
        and lower(m.status)='active'
    )
  for update;

  if not found then
    raise exception using errcode='42501',
      message='Assignment not found or active driver access is unavailable';
  end if;

  if v_assignment.status in ('delivered','cancelled') then
    raise exception using errcode='55000',message='This assignment is already closed';
  end if;

  if p_event_type='pickup' then
    if v_assignment.status not in ('assigned','accepted') then
      raise exception using errcode='55000',
        message='Pickup can only be recorded for an assigned or accepted trip';
    end if;
    v_next_status:='pickup_complete';
  elsif p_event_type='in_transit' then
    if v_assignment.status<>'pickup_complete' then
      raise exception using errcode='55000',message='Record pickup before transit';
    end if;
    v_next_status:='in_transit';
  else
    v_next_status:='exception';
  end if;

  insert into public.krim_driver_trip_events(assignment_id,user_id,event_type,notes)
  values(p_assignment_id,v_user,p_event_type,left(btrim(coalesce(p_notes,'')),1000));

  update public.krim_driver_assignments
  set status=v_next_status,updated_at=now()
  where id=p_assignment_id
  returning * into v_assignment;

  return v_assignment;
end;
$function$;
