-- KRIM SaaS subscription foundation — DESIGN DRAFT ONLY
-- DO NOT APPLY TO PRODUCTION.
-- This draft is intentionally outside supabase/migrations until migration drift,
-- staging baseline, grants, policies and rollback are independently reviewed.
-- No provider checkout, payment capture, recurring billing or tax calculation is implemented.

begin;

create table if not exists public.krim_saas_products (
  id uuid primary key default gen_random_uuid(),
  product_code text not null unique,
  display_name text not null,
  description text,
  lifecycle_status text not null default 'draft'
    check (lifecycle_status in ('draft','published','retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.krim_saas_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.krim_saas_products(id),
  plan_code text not null,
  version integer not null check (version > 0),
  display_name text not null,
  description text,
  lifecycle_status text not null default 'draft'
    check (lifecycle_status in ('draft','published','retired')),
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_code, version)
);

create table if not exists public.krim_saas_plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.krim_saas_plans(id),
  feature_code text not null,
  enabled boolean not null default true,
  quantity_limit bigint,
  configuration jsonb not null default '{}'::jsonb
    check (jsonb_typeof(configuration) = 'object'),
  created_at timestamptz not null default now(),
  unique (plan_id, feature_code),
  check (quantity_limit is null or quantity_limit >= 0)
);

-- A trial is represented as a subscription with status='trialing'.
-- No automatic conversion or payment method is implied.
create table if not exists public.krim_saas_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id bigint not null references public.krim_organizations(id),
  plan_id uuid not null references public.krim_saas_plans(id),
  status text not null default 'pending_approval'
    check (status in (
      'pending_approval','trialing','active','past_due','grace_period',
      'suspended','cancelled','expired'
    )),
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  current_period_starts_at timestamptz,
  current_period_ends_at timestamptz,
  cancel_at_period_end boolean not null default false,
  approved_by uuid,
  approved_at timestamptz,
  cancelled_at timestamptz,
  ended_at timestamptz,
  internal_reference text,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status <> 'trialing')
    or (trial_started_at is not null and trial_ends_at is not null
        and trial_ends_at > trial_started_at)
  )
);

create unique index if not exists krim_saas_one_live_subscription_per_org
  on public.krim_saas_subscriptions (organization_id)
  where status in ('pending_approval','trialing','active','past_due','grace_period');

create index if not exists krim_saas_subscriptions_org_created_idx
  on public.krim_saas_subscriptions (organization_id, created_at desc);

create table if not exists public.krim_saas_entitlements (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.krim_saas_subscriptions(id),
  organization_id bigint not null references public.krim_organizations(id),
  feature_code text not null,
  enabled boolean not null default true,
  quantity_limit bigint,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  source text not null default 'plan'
    check (source in ('plan','manual_grant','manual_revoke')),
  created_at timestamptz not null default now(),
  created_by uuid,
  check (quantity_limit is null or quantity_limit >= 0),
  check (valid_until is null or valid_until > valid_from)
);

create index if not exists krim_saas_entitlements_org_feature_idx
  on public.krim_saas_entitlements (organization_id, feature_code, valid_from desc);

-- Append-only event record. Service role / audited admin function only.
create table if not exists public.krim_saas_audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id bigint references public.krim_organizations(id),
  subscription_id uuid references public.krim_saas_subscriptions(id),
  actor_user_id uuid,
  event_type text not null,
  reason text,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists krim_saas_audit_org_created_idx
  on public.krim_saas_audit_events (organization_id, created_at desc);

-- All exposed tables get RLS. No authenticated client INSERT/UPDATE/DELETE.
alter table public.krim_saas_products enable row level security;
alter table public.krim_saas_plans enable row level security;
alter table public.krim_saas_plan_features enable row level security;
alter table public.krim_saas_subscriptions enable row level security;
alter table public.krim_saas_entitlements enable row level security;
alter table public.krim_saas_audit_events enable row level security;

-- Published catalogue can be read; no client writes.
create policy krim_saas_products_published_read
  on public.krim_saas_products for select to anon, authenticated
  using (lifecycle_status = 'published');

create policy krim_saas_plans_published_read
  on public.krim_saas_plans for select to anon, authenticated
  using (
    lifecycle_status = 'published' and is_public = true
    and exists (
      select 1 from public.krim_saas_products p
      where p.id = product_id and p.lifecycle_status = 'published'
    )
  );

create policy krim_saas_plan_features_published_read
  on public.krim_saas_plan_features for select to anon, authenticated
  using (
    exists (
      select 1 from public.krim_saas_plans p
      join public.krim_saas_products pr on pr.id = p.product_id
      where p.id = plan_id
        and p.lifecycle_status = 'published'
        and p.is_public = true
        and pr.lifecycle_status = 'published'
    )
  );

-- Organisation members may read only their own summary and entitlement rows.
create policy krim_saas_subscriptions_org_read
  on public.krim_saas_subscriptions for select to authenticated
  using (private.krim_has_organization_access(auth.uid(), organization_id));

create policy krim_saas_entitlements_org_read
  on public.krim_saas_entitlements for select to authenticated
  using (private.krim_has_organization_access(auth.uid(), organization_id));

create policy krim_saas_audit_org_read
  on public.krim_saas_audit_events for select to authenticated
  using (
    organization_id is not null
    and private.krim_has_organization_access(auth.uid(), organization_id)
  );

-- Explicit grants: read-only clients; writes are performed by reviewed server functions.
revoke all on public.krim_saas_products, public.krim_saas_plans,
  public.krim_saas_plan_features, public.krim_saas_subscriptions,
  public.krim_saas_entitlements, public.krim_saas_audit_events
  from anon, authenticated;

grant select on public.krim_saas_products, public.krim_saas_plans,
  public.krim_saas_plan_features to anon, authenticated;

grant select on public.krim_saas_subscriptions,
  public.krim_saas_entitlements, public.krim_saas_audit_events
  to authenticated;

-- service_role is privileged and bypasses RLS by platform design.
-- Do not grant authenticated or anon any mutation privileges.
commit;

-- IMPLEMENTATION GATES BEFORE THIS DRAFT CAN BECOME A MIGRATION:
-- 1. Reconcile production/repository migration drift and build a staging baseline.
-- 2. Confirm schema exposure rules and explicit API exposure for these tables.
-- 3. Review FK constraints, uniqueness, index names and existing object collisions.
-- 4. Add database-enforced audit immutability (deny UPDATE/DELETE) and verify grants.
-- 5. Replace generic organization-member read with approved billing-admin/owner policy.
-- 6. Add a server-side, idempotent trial-approval RPC with fixed 30-day duration,
--    AAL2 platform-admin check, no self-approval, one-trial policy and audit event.
-- 7. Add entitlement resolver that checks subscription status AND now() < trial_ends_at
--    and fails closed; clients must never set entitlement or lifecycle state.
-- 8. Add test fixtures for cross-org access, expired trials, revoked membership,
--    duplicate grants, unauthorized mutations and concurrent trial requests.
-- 9. Legal/tax/provider review remains mandatory before charging or recurring billing.
