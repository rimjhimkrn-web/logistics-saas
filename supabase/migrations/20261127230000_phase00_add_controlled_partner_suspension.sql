create or replace function public.krim_admin_set_partner_suspension(
  p_organization_id bigint,
  p_action text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_action text := lower(nullif(btrim(p_action), ''));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_org public.krim_organizations%rowtype;
  v_latest_review record;
  v_assignments bigint := 0;
  v_reservations bigint := 0;
  v_bindings bigint := 0;
  v_old jsonb;
  v_new jsonb;
begin
  if v_user is null
     or coalesce(auth.jwt()->>'aal', '') <> 'aal2'
     or not private.krim_has_permission(v_user, 1::bigint, 'admin.platform') then
    raise exception using errcode = '42501',
      message = 'AAL2 platform administrator access required';
  end if;

  if p_organization_id is null
     or v_action not in ('suspend', 'reinstate')
     or v_reason is null
     or char_length(v_reason) < 20
     or char_length(v_reason) > 2000 then
    raise exception using errcode = '22023',
      message = 'Provide a partner, suspend or reinstate action, and a reason of 20 to 2000 characters';
  end if;

  select *
    into v_org
  from public.krim_organizations o
  where o.id = p_organization_id
    and o.organization_type in ('partner', 'carrier', 'warehouse', 'forwarder')
  for update;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'Partner organization not found';
  end if;

  if v_org.partner_account_mode <> 'registered_business'
     or v_org.partner_verification_status <> 'verified'
     or v_org.partner_lifecycle_status = 'closed'
     or v_org.status = 'inactive' then
    raise exception using errcode = '55000',
      message = 'Only an existing verified registered-business partner can be suspended or reinstated';
  end if;

  if v_action = 'suspend' then
    if v_org.status = 'suspended'
       and v_org.partner_lifecycle_status = 'suspended' then
      raise exception using errcode = '55000',
        message = 'Partner is already suspended';
    end if;

    update public.krim_organizations
       set status = 'suspended',
           partner_lifecycle_status = 'suspended',
           partner_suspended_at = now(),
           partner_reviewed_at = now(),
           partner_reviewed_by = v_user,
           partner_review_notes = v_reason,
           updated_at = now()
     where id = p_organization_id;

  else
    if v_org.status <> 'suspended'
       or v_org.partner_lifecycle_status <> 'suspended' then
      raise exception using errcode = '55000',
        message = 'Only a suspended partner can be reinstated';
    end if;

    select r.status, r.valid_until
      into v_latest_review
    from public.krim_partner_compliance_reviews r
    where r.organization_id = p_organization_id
    order by r.reviewed_at desc, r.id desc
    limit 1;

    if v_org.partner_compliance_status <> 'compliant'
       or v_org.partner_verification_status <> 'verified'
       or v_latest_review.status is distinct from 'approved'
       or v_latest_review.valid_until is null
       or v_latest_review.valid_until <= now() then
      raise exception using errcode = '23514',
        message = 'Reinstatement requires verified identity and a current approved compliance review';
    end if;

    update public.krim_organizations
       set status = 'active',
           partner_lifecycle_status = 'approved',
           partner_reviewed_at = now(),
           partner_reviewed_by = v_user,
           partner_review_notes = v_reason,
           updated_at = now()
     where id = p_organization_id;
  end if;

  select count(*) into v_assignments
  from public.krim_shipment_partner_assignments a
  where a.partner_organization_id = p_organization_id
    and a.status in ('accepted', 'active');

  select count(*) into v_reservations
  from public.krim_capacity_reservations r
  where r.organization_id = p_organization_id
    and r.status in ('held', 'confirmed');

  select count(*) into v_bindings
  from public.krim_capacity_leg_bindings b
  join public.krim_capacity_reservations r
    on r.id = b.reservation_id
  where r.organization_id = p_organization_id
    and b.status in ('pending', 'held', 'confirmed');

  v_old := pg_catalog.jsonb_build_object(
    'status', v_org.status,
    'partner_lifecycle_status', v_org.partner_lifecycle_status,
    'partner_compliance_status', v_org.partner_compliance_status
  );

  v_new := pg_catalog.jsonb_build_object(
    'status', case when v_action = 'suspend' then 'suspended' else 'active' end,
    'partner_lifecycle_status', case when v_action = 'suspend' then 'suspended' else 'approved' end,
    'partner_compliance_status', v_org.partner_compliance_status,
    'action', v_action,
    'reason', v_reason,
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
    v_user, p_organization_id, 'partner.suspension.' || v_action,
    'organization', p_organization_id::text, 'partner_suspension_admin',
    pg_catalog.jsonb_build_object(
      'action', v_action,
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
    'organization_id', p_organization_id,
    'action', v_action,
    'status', v_new->>'status',
    'partner_lifecycle_status', v_new->>'partner_lifecycle_status',
    'affected_active_assignments', v_assignments,
    'affected_live_reservations', v_reservations,
    'affected_live_bindings', v_bindings,
    'requires_operations_review', (v_assignments + v_reservations + v_bindings) > 0,
    'automatic_cancellation_performed', false
  );
end;
$function$;

revoke all on function public.krim_admin_set_partner_suspension(bigint, text, text) from public;
revoke all on function public.krim_admin_set_partner_suspension(bigint, text, text) from anon;
grant execute on function public.krim_admin_set_partner_suspension(bigint, text, text) to authenticated;

comment on function public.krim_admin_set_partner_suspension(bigint, text, text) is
'Phase 00 controlled partner suspension/reinstatement. Requires AAL2 platform admin. Suspension blocks eligibility through organization status/lifecycle. Reinstatement requires current approved compliance. Reports affected assignments/reservations; never cancels them automatically.';
