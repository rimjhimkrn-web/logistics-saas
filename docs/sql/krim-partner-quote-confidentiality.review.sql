-- REVIEW-ONLY security migration: partner commercial quote confidentiality.
-- Production currently grants authenticated SELECT on every column of
-- public.krim_partner_quotes. The live SELECT policy also admits customer
-- organisations related to an opportunity, exposing partner pricing,
-- notes, pricing_snapshot and metadata.
--
-- This change limits direct row access to the owning partner organisation.
-- Customer-facing comparison must use a separate allowlisted customer-safe
-- RPC/view; do not restore customer access to this base table.
--
-- Apply only after staging tests and explicit production approval.

begin;

drop policy if exists "KRIM partner quotes organization access"
  on public.krim_partner_quotes;

create policy "KRIM partner quotes owning organization read"
  on public.krim_partner_quotes
  for select
  to authenticated
  using (
    private.krim_has_organization_access(
      (select auth.uid()),
      partner_organization_id
    )
  );

comment on policy "KRIM partner quotes owning organization read"
  on public.krim_partner_quotes
  is 'Only active members of the owning partner organization may read full partner quote rows. Customer quote presentation must use a separate allowlisted interface.';

commit;

-- STAGING ASSERTIONS (run as authenticated test identities):
-- A. Partner member of quote.partner_organization_id can SELECT own row.
-- B. Customer member of opportunity.customer_organization_id cannot SELECT
--    the base krim_partner_quotes row or any commercial/internal columns.
-- C. Unrelated organization member cannot SELECT the row.
-- D. Anonymous cannot SELECT.
-- E. Partner quote submission/update workflow still succeeds via its
--    existing authorised RPC; do not widen table UPDATE grants.
-- F. Customer-facing quote comparison still works through krim_quotes and
--    contains only customer-approved amount/currency/terms fields.
--
-- ROLLBACK (only if an approved deployment must be reverted):
-- drop policy if exists "KRIM partner quotes owning organization read"
--   on public.krim_partner_quotes;
-- create policy "KRIM partner quotes organization access"
--   on public.krim_partner_quotes for select to authenticated
--   using (
--     private.krim_has_organization_access((select auth.uid()), partner_organization_id)
--     or exists (
--       select 1 from public.krim_partner_opportunities po
--       where po.id = krim_partner_quotes.opportunity_id
--         and private.krim_has_organization_access((select auth.uid()), po.customer_organization_id)
--     )
--   );
