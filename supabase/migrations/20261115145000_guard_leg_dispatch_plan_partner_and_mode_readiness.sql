create or replace function private.krim_guard_leg_dispatch_authorization()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_plan public.krim_shipment_leg_plans%rowtype;
 v_item public.krim_shipment_leg_plan_items%rowtype;
 v_leg public.krim_shipment_legs%rowtype;
 v_org public.krim_organizations%rowtype;
 v_mode text;
begin
 select * into v_leg from public.krim_shipment_legs
 where id=new.shipment_leg_id and shipment_id=new.shipment_id for update;
 if not found or v_leg.leg_plan_item_id is null then
  raise exception using errcode='23514',message='Dispatch authorization requires a leg linked to an activated route plan';
 end if;
 select p.* into v_plan from public.krim_shipment_leg_plans p
 where p.shipment_id=new.shipment_id and p.status='active' and p.total_legs>1 for update;
 if not found then
  raise exception using errcode='23514',message='Dispatch authorization is only available for an active multi-leg route plan';
 end if;
 select i.* into v_item from public.krim_shipment_leg_plan_items i
 where i.id=v_leg.leg_plan_item_id and i.plan_id=v_plan.id
  and i.leg_sequence=v_leg.leg_sequence
  and i.origin_location_id=v_leg.origin_location_id
  and i.destination_location_id=v_leg.destination_location_id
  and i.transport_mode_id=v_leg.transport_mode_id
  and i.partner_organization_id=new.partner_organization_id
  and i.assignment_id=new.partner_assignment_id for update;
 if not found then
  raise exception using errcode='23514',message='Active route plan item, assigned partner and exact shipment leg do not match';
 end if;
 select * into v_org from public.krim_organizations where id=new.partner_organization_id;
 if not found or v_org.status<>'active' or v_org.partner_account_mode<>'registered_business'
  or v_org.partner_verification_status not in ('verified','approved')
  or v_org.partner_lifecycle_status not in ('active','verified')
  or v_org.partner_compliance_status not in ('clear','compliant','approved','verified','not_required','not_applicable')
  or private.krim_partner_compliance_is_current(v_org.id) is not true then
  raise exception using errcode='23514',message='Partner must be an active, verified registered business with current compliance';
 end if;
 if private.krim_partner_capability_covers_shipment_leg(new.partner_organization_id,new.shipment_leg_id) is not true then
  raise exception using errcode='23514',message='Current verified partner capability does not cover this exact shipment leg';
 end if;
 select tm.code into v_mode from public.krim_transport_modes tm where tm.id=v_leg.transport_mode_id;
 if v_mode<>'ROAD' then
  raise exception using errcode='55000',message='Non-road dispatch is held until mode-specific verified resource and execution controls are implemented';
 end if;
 return new;
end;
$function$;
drop trigger if exists trg_krim_guard_leg_dispatch_authorization on public.krim_shipment_leg_dispatch_authorizations;
create trigger trg_krim_guard_leg_dispatch_authorization
before insert or update of shipment_id,shipment_leg_id,partner_assignment_id,partner_organization_id
on public.krim_shipment_leg_dispatch_authorizations
for each row execute function private.krim_guard_leg_dispatch_authorization();
revoke all on function private.krim_guard_leg_dispatch_authorization() from public,anon,authenticated,service_role;