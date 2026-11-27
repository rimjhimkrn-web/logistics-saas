create or replace function public.krim_admin_revoke_partner_service_area(
  p_service_area_id bigint,
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
  v_area public.krim_partner_service_areas%rowtype;
  v_old jsonb;
  v_new jsonb;
  v_assignments bigint := 0;
  v_reservations bigint := 0;
  v_bindings bigint := 0;
begin
  if v_user is null
     or coalesce(auth.jwt()->>'aal', '') <> 'aal2'
     or not private.krim_has_permission(v_user, 1::bigint, 'admin.platform') then
    raise exception using errcode = '42501',
      message = 'AAL2 platform administrator access required';
  end if;

  if p_service_area_id is null
     or v_reason is null
     or char_length(v_reason) < 10
     or char_length(v_reason) > 1000 then
    raise exception using errcode = '22023',
      message = 'A service area and a revocation reason of 10 to 1000 characters are required';
  end if;

  select a.*
    into v_area
  from public.krim_partner_service_areas a
  join public.krim_organizations o on o.id = a.organization_id
  where a.id = p_service_area_id
    and o.organization_type in ('partner', 'carrier', 'warehouse', 'forwarder')
  for update of a, o;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'Partner service area not found';
  end if;

  if v_area.status <> 'active'
     or v_area.metadata->>'workflow_status' <> 'approved' then
    raise exception using errcode = '55000',
      message = 'Only an active approved partner service area can be revoked';
  end if;

  v_old := pg_catalog.jsonb_build_object(
    'service_area_id', v_area.id,
    'organization_id', v_area.organization_id,
    'status', v_area.status,
    'workflow_status', v_area.metadata->>'workflow_status',
    'effective_from', v_area.effective_from,
    'effective_until', v_area.effective_until,
    'metadata', v_area.metadata
  );

  update public.krim_partner_service_areas
     set status = 'suspended',
         metadata = coalesce(metadata, '{}'::jsonb)
           || pg_catalog.jsonb_build_object(
                'workflow_status', 'suspended',
                'revoked_at', now(),
                'revoked_by', v_user,
                'revocation_reason', v_reason
              ),
         updated_at = now()
   where id = p_service_area_id;

  select count(*) into v_assignments
  from public.krim_shipment_partner_assignments a
  where a.partner_organization_id = v_area.organization_id
    and a.status in ('accepted', 'active');

  select count(*) into v_reservations
  from public.krim_capacity_reservations r
  where r.organization_id = v_area.organization_id
    and r.status in ('held', 'confirmed');

  select count(*) into v_bindings
  from public.krim_capacity_leg_bindings b
  join public.krim_capacity_reservations r on r.id = b.reservation_id
  where r.organization_id = v_area.organization_id
    and b.status in ('pending', 'held', 'confirmed');

  v_new := pg_catalog.jsonb_build_object(
    'service_area_id', v_area.id,
    'organization_id', v_area.organization_id,
    'status', 'suspended',
    'workflow_status', 'suspended',
    'revocation_reason', v_reason,
    'affected_active_assignments', v_assignments,
    'affected_live_reservations', v_reservations,
    'affected_live_bindings', v_bindings,
    'requires_operations_review', (v_assignments + v_reservations + v_bindings) > 0
  );

  insert into public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id,
    source, metadata, previous_state, new_state
  )
  values (
    v_user, v_area.organization_id, 'partner.service_area.revoked',
    'partner_service_area', v_area.id::text, 'partner_service_area_revocation',
    pg_catalog.jsonb_build_object(
      'reason', v_reason,
      'affected_active_assignments', v_assignments,
      'affected_live_reservations', v_reservations,
      'affected_live_bindings', v_bindings,
      'automatic_cancellation_performed', false
    ),
    v_old, v_new
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'service_area_id', v_area.id,
    'organization_id', v_area.organization_id,
    'status', 'suspended',
    'workflow_status', 'suspended',
    'affected_active_assignments', v_assignments,
    'affected_live_reservations', v_reservations,
    'affected_live_bindings', v_bindings,
    'requires_operations_review', (v_assignments + v_reservations + v_bindings) > 0,
    'automatic_cancellation_performed', false
  );
end;
$function$;

revoke all on function public.krim_admin_revoke_partner_service_area(bigint, text) from public;
revoke all on function public.krim_admin_revoke_partner_service_area(bigint, text) from anon;
grant execute on function public.krim_admin_revoke_partner_service_area(bigint, text) to authenticated;

comment on function public.krim_admin_revoke_partner_service_area(bigint, text) is
'Phase 00 AAL2 platform-admin revocation of an active approved partner service area. Suspends the area, records audit evidence, reports affected operations and never cancels commercial assignments automatically.';
