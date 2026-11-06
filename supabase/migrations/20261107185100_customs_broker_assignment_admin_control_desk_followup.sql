-- Follow-up: permit AAL2 platform administrators to review customs records
-- and organizations, and allow admin.platform to create broker offers.
drop policy if exists "KRIM customs records platform admin read" on public.krim_shipment_customs;
create policy "KRIM customs records platform admin read" on public.krim_shipment_customs
for select to authenticated using (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'));
drop policy if exists "KRIM organizations platform admin read" on public.krim_organizations;
create policy "KRIM organizations platform admin read" on public.krim_organizations
for select to authenticated using (coalesce(auth.jwt()->>'aal','aal1')='aal2' and private.krim_has_permission((select auth.uid()),1,'admin.platform'));

create or replace function private.krim_customs_broker_assign(
 p_customs_record_id bigint,p_broker_organization_id bigint,p_actor_organization_id bigint,p_note text default ''
) returns bigint language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_shipment_id bigint; v_customer_org bigint; v_actor_type text; v_assignment_id bigint; v_country_id bigint;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Multi-factor authentication required'; end if;
 select c.shipment_id,s.customer_organization_id,c.country_id into v_shipment_id,v_customer_org,v_country_id from public.krim_shipment_customs c join public.krim_shipments s on s.id=c.shipment_id where c.id=p_customs_record_id for update of c;
 if v_shipment_id is null then raise exception 'Customs record not found'; end if;
 if v_country_id is null then raise exception 'Customs jurisdiction is missing; broker assignment is blocked'; end if;
 select organization_type into v_actor_type from public.krim_organizations where id=p_actor_organization_id and status='active';
 if v_actor_type is null then raise exception 'Active actor organization required'; end if;
 if p_actor_organization_id=v_customer_org then
  if not public.krim_has_permission(v_user,p_actor_organization_id,'shipment.update') then raise exception 'Shipment update permission required'; end if;
 elsif v_actor_type in ('platform','operations') then
  if not (public.krim_has_permission(v_user,p_actor_organization_id,'compliance.manage') or (v_actor_type='platform' and public.krim_has_permission(v_user,p_actor_organization_id,'admin.platform'))) then raise exception 'Platform compliance or administrator permission required'; end if;
 else raise exception 'Actor organization is not authorized for this shipment'; end if;
 if not exists(select 1 from public.krim_organizations o where o.id=p_broker_organization_id and o.organization_type='customs' and o.status='active') then raise exception 'Broker organization is not an active customs organization'; end if;
 if not exists(select 1 from public.krim_customs_broker_licenses l where l.organization_id=p_broker_organization_id and l.country_id=v_country_id and l.status='approved' and (l.valid_from is null or l.valid_from<=current_date) and (l.valid_until is null or l.valid_until>=current_date)) then raise exception 'Broker has no currently approved licence for this customs jurisdiction; assignment is blocked'; end if;
 if exists(select 1 from public.krim_customs_broker_assignments a where a.customs_record_id=p_customs_record_id and a.assignment_status in ('proposed','accepted')) then raise exception 'This customs record already has an open broker assignment. Revoke or resolve it before assigning another broker.'; end if;
 insert into public.krim_customs_broker_assignments(customs_record_id,shipment_id,broker_organization_id,jurisdiction_country_id,assignment_note,assigned_by) values(p_customs_record_id,v_shipment_id,p_broker_organization_id,v_country_id,left(coalesce(p_note,''),2000),v_user) returning id into v_assignment_id;
 insert into public.krim_customs_broker_assignment_events(assignment_id,shipment_id,customs_record_id,event_type,actor_user_id,actor_organization_id,event_note) values(v_assignment_id,v_shipment_id,p_customs_record_id,'proposed',v_user,p_actor_organization_id,left(coalesce(p_note,''),2000));
 return v_assignment_id;
end;$function$;
revoke all on function private.krim_customs_broker_assign(bigint,bigint,bigint,text) from public,anon,authenticated;
grant execute on function private.krim_customs_broker_assign(bigint,bigint,bigint,text) to authenticated;
