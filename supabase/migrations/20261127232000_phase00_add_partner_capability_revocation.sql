create or replace function public.krim_admin_revoke_partner_capability(
  p_capability_id bigint,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_org_id bigint;
  v_status text;
  v_active boolean;
  v_old jsonb;
  v_new jsonb;
begin
  if v_user is null
     or coalesce(auth.jwt()->>'aal', '') <> 'aal2'
     or not private.krim_has_permission(v_user, 1::bigint, 'admin.platform') then
    raise exception using errcode = '42501',
      message = 'AAL2 platform administrator access required';
  end if;

  if p_capability_id is null
     or v_reason is null
     or char_length(v_reason) < 10
     or char_length(v_reason) > 1000 then
    raise exception using errcode = '22023',
      message = 'A capability and a revocation reason of 10 to 1000 characters are required';
  end if;

  select c.organization_id, c.verification_status, c.active,
         pg_catalog.jsonb_build_object(
           'capability_id', c.id,
           'active', c.active,
           'verification_status', c.verification_status,
           'effective_from', c.effective_from,
           'effective_until', c.effective_until,
           'metadata', c.metadata
         )
    into v_org_id, v_status, v_active, v_old
  from public.krim_partner_capabilities c
  join public.krim_organizations o on o.id = c.organization_id
  where c.id = p_capability_id
    and o.organization_type in ('partner', 'carrier', 'warehouse', 'forwarder')
  for update of c, o;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'Partner capability not found';
  end if;

  if v_status <> 'verified' or v_active is not true then
    raise exception using errcode = '55000',
      message = 'Only an active verified capability can be revoked';
  end if;

  update public.krim_partner_capabilities
     set active = false,
         verification_status = 'suspended',
         metadata = coalesce(metadata, '{}'::jsonb)
           || pg_catalog.jsonb_build_object(
                'revoked_at', now(),
                'revoked_by', v_user,
                'revocation_reason', v_reason
              )
   where id = p_capability_id;

  v_new := pg_catalog.jsonb_build_object(
    'capability_id', p_capability_id,
    'active', false,
    'verification_status', 'suspended',
    'revocation_reason', v_reason
  );

  insert into public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id,
    source, metadata, previous_state, new_state
  )
  values (
    v_user, v_org_id, 'partner.capability.revoked',
    'partner_capability', p_capability_id::text,
    'partner_capability_revocation',
    pg_catalog.jsonb_build_object(
      'reason', v_reason,
      'revocation_is_not_assignment_cancellation', true
    ),
    v_old, v_new
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'capability_id', p_capability_id,
    'organization_id', v_org_id,
    'active', false,
    'verification_status', 'suspended',
    'revocation_reason', v_reason,
    'existing_assignments_cancelled', false
  );
end;
$function$;

revoke all on function public.krim_admin_revoke_partner_capability(bigint, text) from public;
revoke all on function public.krim_admin_revoke_partner_capability(bigint, text) from anon;
grant execute on function public.krim_admin_revoke_partner_capability(bigint, text) to authenticated;

comment on function public.krim_admin_revoke_partner_capability(bigint, text) is
'Phase 00 AAL2 platform-admin revocation of an active verified partner capability. Deactivates capability, records immutable audit evidence and does not cancel existing commercial assignments.';
