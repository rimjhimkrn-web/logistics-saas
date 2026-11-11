-- REVIEW ONLY — DO NOT APPLY DIRECTLY TO PRODUCTION.
-- KRIM partner quote confidentiality containment proposal.
--
-- Verified live state:
--   authenticated has table SELECT on public.krim_partner_quotes.
--   The current SELECT policy admits the partner organisation OR the
--   customer organisation attached to the opportunity.
--   Customer quote comparison reads public.krim_quotes, not this table.
--   Partner quote history and partner bidding pages read this table scoped
--   to the partner's own organization.
--   Award and internal customer-quote preparation paths use guarded
--   SECURITY DEFINER functions; inspect their current definitions before rollout.
--
-- Proposed change: direct authenticated table reads are partner-org-only.
-- Customer-facing approved quote details remain in krim_quotes through the
-- existing internal quote-preparation workflow. Do not expose raw partner
-- notes, pricing_snapshot, or metadata to customer sessions.

begin;

drop policy if exists "KRIM partner quotes organization access"
  on public.krim_partner_quotes;

create policy "KRIM partner quotes partner organization access"
on public.krim_partner_quotes
for select
to authenticated
using (
  private.krim_has_organization_access(
    (select auth.uid()),
    partner_organization_id
  )
);

-- Before COMMIT in a controlled staging environment, validate:
-- 1. Partner member can read own partner quote rows.
-- 2. Customer member cannot select raw partner quote rows.
-- 3. Unrelated customer/partner cannot select the rows.
-- 4. Customer quote comparison still reads only krim_quotes.
-- 5. krim_award_partner_quote and krim_award_partner_quote_for_checkout
--    still work for authorized customer members.
-- 6. Internal customer quote preparation still works and emits only the
--    customer-approved fields into krim_quotes.
-- 7. Partner quote history, submission, update and assignment response work.
--
-- Rollback (only if approved and only after preserving the exact live policy):
-- drop policy if exists "KRIM partner quotes partner organization access"
--   on public.krim_partner_quotes;
-- create policy "KRIM partner quotes organization access"
-- on public.krim_partner_quotes for select to authenticated
-- using (
--   private.krim_has_organization_access((select auth.uid()), partner_organization_id)
--   OR EXISTS (
--     SELECT 1 FROM public.krim_partner_opportunities po
--     WHERE po.id = krim_partner_quotes.opportunity_id
--       AND private.krim_has_organization_access((select auth.uid()), po.customer_organization_id)
--   )
-- );

rollback;
