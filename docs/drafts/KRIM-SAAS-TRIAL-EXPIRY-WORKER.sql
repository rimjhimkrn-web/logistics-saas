-- KRIM SaaS trial expiry worker — DESIGN DRAFT ONLY
-- Run only after subscription schema + RPCs have been reviewed and deployed to staging.
-- Do not enable pg_cron or execute against production as part of this draft.

begin;

create table if not exists public.krim_saas_admin_request_ledger (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  action_code text not null,
  payload_hash text not null,
  actor_user_id uuid not null,
  result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.krim_saas_admin_request_ledger enable row level security;
revoke all on public.krim_saas_admin_request_ledger from anon, authenticated;
-- No client policy or client grant. Server-side privileged functions only.

create or replace function public.krim_saas_expire_trials()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count integer := 0;
begin
  with expired as (
    update public.krim_saas_subscriptions s
    set status = 'expired',
        ended_at = coalesce(s.ended_at, clock_timestamp()),
        updated_at = clock_timestamp()
    where s.status = 'trialing'
      and s.trial_ends_at is not null
      and s.trial_ends_at <= clock_timestamp()
    returning s.id, s.organization_id, s.trial_ends_at
  ), events as (
    insert into public.krim_saas_audit_events (
      organization_id, subscription_id, event_type, reason, metadata
    )
    select organization_id, id, 'saas_trial_expired',
           'Trial reached its fixed expiry timestamp',
           jsonb_build_object('trial_ends_at', trial_ends_at)
    from expired
    returning id
  )
  select count(*) into v_count from events;

  return v_count;
end;
$$;

revoke all on function public.krim_saas_expire_trials() from public, anon, authenticated;
grant execute on function public.krim_saas_expire_trials() to service_role;

commit;

-- Operational requirements before scheduling:
-- 1. First deploy and test in staging with clock-controlled expiry fixtures.
-- 2. The entitlement resolver must fail closed at trial_ends_at even if this worker is delayed.
-- 3. Schedule only after pg_cron availability, ownership, service_role invocation and alerting are reviewed.
-- 4. Record worker run counts and failures in a monitored operations log; alert on repeated failures.
-- 5. Ensure audit events cannot be updated/deleted by any normal app or admin path.
-- 6. Add a unique request ledger check to trial approval: same request_id + same payload is idempotent;
--    same request_id + different payload is rejected. This table alone does not implement that check.
-- 7. Never auto-convert expired trials into paid subscriptions.
