-- KRIM SaaS audit immutability + billing-read policy design
-- REVIEW DRAFT ONLY. Depends on the SaaS foundation draft; do not apply to production.
-- This file intentionally contains no grants to clients and no data migration.

begin;

-- Prevent ordinary SQL UPDATE/DELETE paths from rewriting SaaS audit history.
-- Table owners/superusers can still bypass triggers by design; restrict ownership and
-- operational access to the migration role and tightly controlled service-role functions.
create or replace function public.krim_saas_reject_audit_mutation()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'KRIM SaaS audit events are append-only'
    using errcode = '55000';
end;
$$;

drop trigger if exists krim_saas_audit_no_update on public.krim_saas_audit_events;
create trigger krim_saas_audit_no_update
before update on public.krim_saas_audit_events
for each row execute function public.krim_saas_reject_audit_mutation();

drop trigger if exists krim_saas_audit_no_delete on public.krim_saas_audit_events;
create trigger krim_saas_audit_no_delete
before delete on public.krim_saas_audit_events
for each row execute function public.krim_saas_reject_audit_mutation();

-- Do not grant direct client writes to audit events. Server-side service functions
-- may INSERT, but no application role should receive UPDATE/DELETE/TRUNCATE.
revoke insert, update, delete, truncate, references, trigger
  on public.krim_saas_audit_events from anon, authenticated;
grant select on public.krim_saas_audit_events to authenticated;

-- Billing visibility policy decision:
-- Until a dedicated billing permission exists, restrict subscription and audit reads
-- to active organisation owners only. Do NOT equate general membership with billing access.
-- The existing krim_organization_members.role values must be confirmed in staging before
-- this policy is adopted. The policy below uses the canonical role string 'owner';
-- if the production role vocabulary differs, update it only after verified catalog review.
drop policy if exists krim_saas_subscriptions_org_read on public.krim_saas_subscriptions;
create policy krim_saas_subscriptions_owner_read
on public.krim_saas_subscriptions
for select to authenticated
using (
  exists (
    select 1
    from public.krim_organization_members m
    join public.krim_organizations o
      on o.id = m.organization_id
     and o.status = 'active'
    where m.organization_id = krim_saas_subscriptions.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and lower(m.role) = 'owner'
  )
);

drop policy if exists krim_saas_audit_org_read on public.krim_saas_audit_events;
create policy krim_saas_audit_owner_read
on public.krim_saas_audit_events
for select to authenticated
using (
  organization_id is not null
  and exists (
    select 1
    from public.krim_organization_members m
    join public.krim_organizations o
      on o.id = m.organization_id
     and o.status = 'active'
    where m.organization_id = krim_saas_audit_events.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and lower(m.role) = 'owner'
  )
);

commit;

-- Mandatory validation before adopting:
-- 1. Verify actual owner role spelling/case and whether multi-owner organisations are allowed.
-- 2. Confirm service_role INSERT grants and no UPDATE/DELETE/TRUNCATE grants remain.
-- 3. Test anon, ordinary member, finance manager, owner, platform admin and service_role.
-- 4. Verify SECURITY INVOKER trigger function execution rights under the insert/update/delete
--    paths and ensure no owner-controlled RPC can bypass the append-only boundary.
-- 5. Review table ownership and privileged maintenance procedures. A trigger is not protection
--    against superuser/table-owner disablement.
-- 6. Prefer adding a dedicated billing.view permission and using private.krim_has_permission()
--    once permission governance is approved; owner-only is the interim conservative default.
-- 7. Do not deploy until migration drift is reconciled and staging tests pass.
