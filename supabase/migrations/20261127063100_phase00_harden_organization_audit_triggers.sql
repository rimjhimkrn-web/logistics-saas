-- Phase 00: harden organization audit trigger functions.
-- These functions run only as table triggers; keep the audit write fully qualified
-- and remove the mutable public schema from their SECURITY DEFINER search path.

create or replace function public.krim_log_organization_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.krim_audit_events (
    actor_user_id,
    organization_id,
    event_type,
    entity_type,
    entity_id,
    source,
    metadata
  )
  values (
    auth.uid(),
    new.organization_id,
    'organization_member_added',
    'organization_member',
    new.organization_id,
    'system',
    pg_catalog.jsonb_build_object(
      'user_id', new.user_id,
      'role', new.role,
      'status', new.status
    )
  );

  return new;
end;
$function$;

create or replace function public.krim_log_organization_creation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.krim_audit_events (
    actor_user_id,
    organization_id,
    event_type,
    entity_type,
    entity_id,
    source,
    metadata
  )
  values (
    auth.uid(),
    new.id,
    'organization_created',
    'organization',
    new.id,
    'system',
    pg_catalog.jsonb_build_object(
      'organization_type', new.organization_type,
      'legal_name', new.legal_name,
      'display_name', new.display_name,
      'country_id', new.country_id,
      'market_id', new.market_id,
      'default_currency_code', new.default_currency_code
    )
  );

  return new;
end;
$function$;

revoke all on function public.krim_log_organization_membership() from public, anon, authenticated;
revoke all on function public.krim_log_organization_creation() from public, anon, authenticated;
