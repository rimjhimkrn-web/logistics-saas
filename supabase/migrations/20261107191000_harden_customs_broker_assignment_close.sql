-- Enforce AAL2, meaningful audit notes and admin-platform authorization
-- for customs broker assignment revocation and completion.
create or replace function private.krim_customs_broker_close(p_assignment_id bigint,p_action text,p_actor_organization_id bigint,p_note text default '')
returns boolean language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid(); v_broker_org bigint; v_shipment_id bigint; v_record_id bigint; v_customer_org bigint; v_actor_type text; v_status text; v_event text;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Multi-factor authentication required'; end if;
 if p_action not in ('revoke','complete') then raise exception 'Invalid assignment action'; end if;
 if length(trim(coalesce(p_note,'')))<10 then raise exception 'A meaningful lifecycle note of at least 10 characters is required'; end if;
 select a.broker_organization_id,a.shipment_id,a.customs_record_id,a.assignment_status,s.customer_organization_id
 into v_broker_org,v_shipment_id,v_record_id,v_status,v_customer_org
 from public.krim_customs_broker_assignments a join public.krim_shipments s on s.id=a.shipment_id where a.id=p_assignment_id for update of a;
 if v_broker_org is null then raise exception 'Assignment not found'; end if;
 select organization_type into v_actor_type from public.krim_organizations where id=p_actor_organization_id and status='active';
 if v_actor_type is null then raise exception 'Active actor organization required'; end if;
 if p_actor_organization_id=v_customer_org then
  if not public.krim_has_permission(v_user,p_actor_organization_id,'shipment.update') then raise exception 'Shipment update permission required'; end if;
 elsif v_actor_type in ('platform','operations') then
  if not (public.krim_has_permission(v_user,p_actor_organization_id,'compliance.manage') or (v_actor_type='platform' and public.krim_has_permission(v_user,p_actor_organization_id,'admin.platform'))) then raise exception 'Platform compliance or administrator permission required'; end if;
 else raise exception 'Actor organization is not authorized for this shipment'; end if;
 if p_action='revoke' and v_status in ('proposed','accepted') then
  update public.krim_customs_broker_assignments set assignment_status='revoked',revoked_by=v_user,revoked_at=now(),assignment_note=left(trim(p_note),2000),updated_at=now() where id=p_assignment_id;
  v_event:='revoked';
 elsif p_action='complete' and v_status='accepted' then
  update public.krim_customs_broker_assignments set assignment_status='completed',completed_by=v_user,completed_at=now(),assignment_note=left(trim(p_note),2000),updated_at=now() where id=p_assignment_id;
  v_event:='completed';
 else raise exception 'Invalid action or assignment state'; end if;
 insert into public.krim_customs_broker_assignment_events(assignment_id,shipment_id,customs_record_id,event_type,actor_user_id,actor_organization_id,event_note)
 values(p_assignment_id,v_shipment_id,v_record_id,v_event,v_user,p_actor_organization_id,left(trim(p_note),2000));
 return true;
end;$function$;
revoke all on function private.krim_customs_broker_close(bigint,text,bigint,text) from public,anon,authenticated;
grant execute on function private.krim_customs_broker_close(bigint,text,bigint,text) to authenticated;
