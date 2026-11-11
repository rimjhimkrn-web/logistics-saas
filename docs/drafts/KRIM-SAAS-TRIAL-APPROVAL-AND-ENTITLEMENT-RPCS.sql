-- KRIM SaaS trial approval + entitlement resolver — REVIEW DRAFT ONLY
-- Security revision: approval RPC is service_role-only; entitlement resolver is invoker.
-- Companion to docs/drafts/KRIM-SAAS-SUBSCRIPTION-FOUNDATION-DRAFT.sql
-- DO NOT APPLY TO PRODUCTION. Requires a reconciled staging schema and security review.
-- No checkout, payment capture, recurring billing or auto-conversion is included.

begin;

-- The requesting principal is retained so the approver cannot approve their own request.
alter table public.krim_saas_subscriptions
  add column if not exists requested_by uuid;

-- Backfill is intentionally omitted: draft-only schema has no live records.
-- Before implementation, make requested_by NOT NULL for new trial requests.

create index if not exists krim_saas_trial_expiry_idx
  on public.krim_saas_subscriptions (trial_ends_at)
  where status = 'trialing';

-- Platform admin approves a previously created pending_approval request.
-- Trial start/end are calculated by the database; client cannot choose duration.
create or replace function public.krim_saas_approve_trial(
  p_subscription_id uuid,
  p_request_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  -- p_actor_user_id is supplied only by the authenticated Edge Function after
  -- validating the caller's JWT and AAL2. EXECUTE is service_role-only.
  v_actor uuid := p_actor_user_id;
  v_sub public.krim_saas_subscriptions%rowtype;
  v_now timestamptz := clock_timestamp();
  v_is_platform_admin boolean := false;
  v_feature_count integer := 0;
begin
  if v_actor is null then
    raise exception 'Validated actor required' using errcode = '28000';
  end if;

  select exists (
    select 1
    from public.krim_user_role_assignments ura
    join public.krim_security_roles r on r.id = ura.role_id
    where ura.user_id = v_actor
      and ura.is_active = true
      and ura.organization_id is null
      and r.role_code in ('platform_admin','platform_superadmin')
  ) into v_is_platform_admin;

  if not v_is_platform_admin then
    raise exception 'Platform administration access denied' using errcode = '42501';
  end if;

  select * into v_sub
  from public.krim_saas_subscriptions
  where id = p_subscription_id
  for update;

  if not found then
    raise exception 'Trial request not found' using errcode = 'P0002';
  end if;

  -- Safe retry: already approved returns current state without a second grant.
  if v_sub.status = 'trialing'
     and v_sub.trial_started_at is not null
     and v_sub.trial_ends_at is not null then
    return jsonb_build_object(
      'ok', true, 'idempotent', true, 'subscription_id', v_sub.id,
      'status', v_sub.status, 'trial_ends_at', v_sub.trial_ends_at
    );
  end if;

  if v_sub.status <> 'pending_approval' then
    raise exception 'Subscription is not awaiting trial approval' using errcode = '55000';
  end if;

  if v_sub.requested_by is not null and v_sub.requested_by = v_actor then
    raise exception 'Self-approval is not permitted' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.krim_saas_subscriptions s
    where s.organization_id = v_sub.organization_id
      and s.id <> v_sub.id
      and s.status in ('trialing','active','past_due','grace_period')
  ) then
    raise exception 'Organization already has a live subscription' using errcode = '23505';
  end if;

  update public.krim_saas_subscriptions
  set status = 'trialing',
      trial_started_at = v_now,
      trial_ends_at = v_now + interval '30 days',
      current_period_starts_at = v_now,
      current_period_ends_at = v_now + interval '30 days',
      approved_by = v_actor,
      approved_at = v_now,
      updated_at = v_now
  where id = v_sub.id;

  insert into public.krim_saas_entitlements (
    subscription_id, organization_id, feature_code, enabled,
    quantity_limit, valid_from, valid_until, source, created_by
  )
  select v_sub.id, v_sub.organization_id, f.feature_code, f.enabled,
         f.quantity_limit, v_now, v_now + interval '30 days', 'plan', v_actor
  from public.krim_saas_plan_features f
  where f.plan_id = v_sub.plan_id
  on conflict do nothing;

  get diagnostics v_feature_count = row_count;

  insert into public.krim_saas_audit_events (
    organization_id, subscription_id, actor_user_id,
    event_type, reason, metadata
  ) values (
    v_sub.organization_id, v_sub.id, v_actor,
    'saas_trial_approved', 'Approved by platform administrator',
    jsonb_build_object(
      'request_id', p_request_id,
      'trial_days', 30,
      'trial_ends_at', v_now + interval '30 days',
      'entitlement_rows_created', v_feature_count
    )
  );

  return jsonb_build_object(
    'ok', true, 'idempotent', false, 'subscription_id', v_sub.id,
    'status', 'trialing', 'trial_started_at', v_now,
    'trial_ends_at', v_now + interval '30 days',
    'entitlement_rows_created', v_feature_count
  );
end;
$$;

-- Entitlement resolver: server checks membership, subscription state and effective dates.
-- A stale status='trialing' cannot grant access after the stored expiry timestamp.
create or replace function public.krim_saas_get_my_entitlements(
  p_organization_id bigint
)
returns table (
  feature_code text,
  enabled boolean,
  quantity_limit bigint,
  effective_until timestamptz
)
language sql
stable
security invoker
set search_path = pg_catalog, public, private, auth
as $$
  select e.feature_code,
         e.enabled,
         e.quantity_limit,
         least(
           coalesce(e.valid_until, 'infinity'::timestamptz),
           coalesce(s.trial_ends_at, s.current_period_ends_at, 'infinity'::timestamptz)
         ) as effective_until
  from public.krim_saas_entitlements e
  join public.krim_saas_subscriptions s on s.id = e.subscription_id
  where e.organization_id = p_organization_id
    and s.organization_id = p_organization_id
    and private.krim_has_organization_access(auth.uid(), p_organization_id)
    and s.status in ('trialing','active','grace_period')
    and e.enabled = true
    and e.valid_from <= now()
    and (e.valid_until is null or e.valid_until > now())
    and (
      s.status <> 'trialing'
      or (s.trial_ends_at is not null and s.trial_ends_at > now())
    )
    and (
      s.status = 'trialing'
      or s.current_period_ends_at is null
      or s.current_period_ends_at > now()
    );
$$;

-- Only authenticated users can call the entitlement resolver; it returns only their org rows.
-- The approval RPC is callable only by the trusted Edge Function's service-role client.
-- The Edge Function must independently validate the caller JWT, AAL2, platform role,
-- requester != approver, and request idempotency before passing p_actor_user_id.
revoke all on function public.krim_saas_approve_trial(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.krim_saas_approve_trial(uuid,uuid,uuid) to service_role;

-- Entitlement resolution is deliberately SECURITY INVOKER (the default): RLS on the
-- entitlement/subscription tables remains in force for the authenticated caller.
revoke all on function public.krim_saas_get_my_entitlements(bigint) from public, anon;
grant execute on function public.krim_saas_get_my_entitlements(bigint) to authenticated;

commit;

-- CRITICAL REVIEW NOTES:
-- 1. p_request_id idempotency is logged but not yet protected by a unique idempotency table.
--    Add a unique request ledger and reject reuse with a different payload before release.
-- 2. The current subscription table draft's unique partial index includes pending_approval.
--    Confirm intended one-pending-request-per-org policy and race behavior in staging.
-- 3. Approval RPC rechecks the platform role for the actor but trusts the service-role
--    Edge Function to validate the user's JWT and AAL2 before passing p_actor_user_id.
--    Never grant this RPC to anon/authenticated; only service_role may execute it.
-- 4. Entitlement resolver is SECURITY INVOKER; verify authenticated SELECT grants and RLS
--    policies permit only the caller's active organisation memberships.
-- 5. Add an automated expiry worker that transitions trialing -> expired and appends audit events.
--    Resolver already fails closed at expiry even if the worker is delayed.
-- 6. Add immutable audit enforcement and a test for service-role / owner mutation paths.
-- 7. Add cancellation, manual grant/revoke, plan versioning, renewal, invoice and provider webhook
--    workflows only after separate approval and tax/provider review.
-- 8. Test concurrency, duplicate retries, expired trials, wrong tenant, revoked membership,
--    non-AAL2, non-platform-admin and self-approval in isolated staging.
