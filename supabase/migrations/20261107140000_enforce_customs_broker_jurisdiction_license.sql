create or replace function private.krim_customs_broker_respond(
 p_assignment_id bigint,p_accept boolean,p_note text default ''
) returns boolean language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_user uuid:=auth.uid(); v_broker_org bigint; v_shipment_id bigint; v_record_id bigint; v_status text; v_country_id bigint;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 select a.broker_organization_id,a.shipment_id,a.customs_record_id,a.assignment_status,c.country_id
 into v_broker_org,v_shipment_id,v_record_id,v_status,v_country_id
 from public.krim_customs_broker_assignments a
 join public.krim_shipment_customs c on c.id=a.customs_record_id and c.shipment_id=a.shipment_id
 where a.id=p_assignment_id for update of a;
 if v_broker_org is null then raise exception 'Assignment not found'; end if;
 if not exists(select 1 from public.krim_organization_members m where m.organization_id=v_broker_org and m.user_id=v_user and m.status='active')
   or not public.krim_has_permission(v_user,v_broker_org,'compliance.view') then raise exception 'Active authorized broker membership required'; end if;
 if v_status<>'proposed' then raise exception 'Assignment is no longer awaiting response'; end if;
 if p_accept then
  if v_country_id is null then raise exception 'Customs jurisdiction is missing; broker acceptance is blocked'; end if;
  if not exists(select 1 from public.krim_customs_broker_licenses l where l.organization_id=v_broker_org and l.country_id=v_country_id and l.status='approved'
   and (l.valid_from is null or l.valid_from<=current_date) and (l.valid_until is null or l.valid_until>=current_date)) then
   raise exception 'No currently approved broker licence exists for this customs jurisdiction';
  end if;
 end if;
 update public.krim_customs_broker_assignments set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
 accepted_by=case when p_accept then v_user else null end,accepted_at=case when p_accept then now() else null end,
 rejected_by=case when not p_accept then v_user else null end,rejected_at=case when not p_accept then now() else null end,
 assignment_note=case when coalesce(p_note,'')='' then assignment_note else left(p_note,2000) end,updated_at=now() where id=p_assignment_id;
 insert into public.krim_customs_broker_assignment_events(assignment_id,shipment_id,customs_record_id,event_type,actor_user_id,actor_organization_id,event_note)
 values(p_assignment_id,v_shipment_id,v_record_id,case when p_accept then 'accepted' else 'rejected' end,v_user,v_broker_org,left(coalesce(p_note,''),2000));
 return true;
end; $$;
revoke all on function private.krim_customs_broker_respond(bigint,boolean,text) from public,anon,authenticated;
grant execute on function private.krim_customs_broker_respond(bigint,boolean,text) to authenticated;
