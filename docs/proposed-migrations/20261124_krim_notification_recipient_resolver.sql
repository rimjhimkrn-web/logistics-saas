-- PROPOSED ONLY: reviewed draft; do not apply until migration-history reconciliation
-- and a disposable-database test run are complete.
-- Resolves user identities only. It deliberately does not read email/phone,
-- create outbox rows, or send messages.

create or replace function krim_internal.resolve_shipment_notification_recipients(
  p_shipment_id bigint,
  p_recipient_type text,
  p_intent_code text
)
returns table (
  recipient_type text,
  organization_id bigint,
  user_id uuid,
  member_role text,
  resolution_source text,
  preferred_language_code text,
  timezone text
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_shipment_id is null or p_shipment_id <= 0 then
    raise exception 'invalid_shipment_id' using errcode = '22023';
  end if;

  if p_recipient_type is null or p_recipient_type not in ('customer', 'partner') then
    raise exception 'unsupported_recipient_type' using errcode = '22023';
  end if;

  if p_intent_code is null or p_intent_code not in (
    'shipment.lifecycle.confirmed',
    'shipment.lifecycle.dispatched',
    'shipment.lifecycle.delivered',
    'shipment.lifecycle.exception',
    'shipment.lifecycle.assigned'
  ) then
    raise exception 'unsupported_notification_intent' using errcode = '22023';
  end if;

  if (p_recipient_type = 'customer' and p_intent_code not in (
        'shipment.lifecycle.confirmed','shipment.lifecycle.dispatched',
        'shipment.lifecycle.delivered','shipment.lifecycle.exception'))
     or (p_recipient_type = 'partner' and p_intent_code <> 'shipment.lifecycle.assigned') then
    raise exception 'notification_intent_recipient_mismatch' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.krim_shipments s
    where s.id = p_shipment_id
  ) then
    raise exception 'shipment_not_found' using errcode = 'P0002';
  end if;

  if p_recipient_type = 'customer' then
    return query
    select distinct
      'customer'::text,
      s.customer_organization_id,
      cil.user_id,
      m.role,
      'verified_customer_identity_and_active_membership'::text,
      coalesce(wp.preferred_language_code, cap.language_code),
      coalesce(wp.preferred_timezone, org.timezone)
    from public.krim_shipments s
    join public.krim_organizations org
      on org.id = s.customer_organization_id
     and org.status = 'active'
     and org.organization_type in ('customer', 'enterprise')
    join public.krim_customer_identity_links cil
      on cil.organization_id = org.id
     and cil.identity_status = 'verified'
     and cil.verified_at is not null
    join public.krim_customer_acquisition_profiles cap
      on cap.id = cil.customer_profile_id
     and (cap.organization_id is null or cap.organization_id = org.id)
     and cap.status = 'active'
    join public.krim_customer_workspace_profiles wp
      on wp.customer_profile_id = cap.id
     and wp.organization_id = org.id
     and wp.workspace_status = 'active'
     and wp.account_status = 'active'
    join public.krim_organization_members m
      on m.organization_id = org.id
     and m.user_id = cil.user_id
     and m.status = 'active'
     and m.role in ('owner','admin','operator','member')
    where s.id = p_shipment_id
      and s.customer_organization_id is not null
      and p_intent_code in ('shipment.lifecycle.confirmed','shipment.lifecycle.dispatched','shipment.lifecycle.delivered','shipment.lifecycle.exception');
    return;
  end if;

  return query
  select distinct
    'partner'::text,
    a.partner_organization_id,
    m.user_id,
    m.role,
    'active_shipment_assignment_and_verified_partner_membership'::text,
    null::text,
    org.timezone
  from public.krim_shipment_partner_assignments a
  join public.krim_organizations org
    on org.id = a.partner_organization_id
   and org.status = 'active'
   and org.organization_type in ('partner', 'carrier', 'warehouse', 'forwarder', 'customs')
   and org.partner_lifecycle_status = 'active'
   and org.partner_verification_status = 'verified'
   and org.partner_compliance_status = 'compliant'
  join public.krim_organization_members m
    on m.organization_id = org.id
   and m.status = 'active'
   and m.role in ('owner','admin','manager','dispatcher','operator')
  where a.shipment_id = p_shipment_id
    and a.status in ('offered', 'accepted', 'active')
    and p_intent_code = 'shipment.lifecycle.assigned';
end;
$function$;

revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from public;
revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from anon;
revoke all on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) from authenticated;
grant execute on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text) to service_role;

comment on function krim_internal.resolve_shipment_notification_recipients(bigint, text, text)
is 'Internal identity-only resolver for shipment notification recipients with workflow-code role allowlists; service_role only; never sends messages.';
