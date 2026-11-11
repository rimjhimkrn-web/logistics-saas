# KRIM durable signup consent evidence — implementation review

Date: 2026-11-11  
Status: draft branch only; no production database changes.

## Live production findings (read-only inspection)

- `public.krim_user_consent_events` already exists with columns `id`, `user_id`, `consent_type`, `granted`, `policy_version`, and server-defaulted `created_at`.
- RLS is enabled. Authenticated users can read only their own events.
- Authenticated users currently have direct INSERT privilege plus an own-user INSERT policy. That permits users to create arbitrary consent rows for themselves and weakens the evidentiary value of the table.
- The current `public.handle_new_customer()` Auth trigger function inserts one combined `terms_and_privacy` event when `terms_accepted=true`. It uses the submitted `terms_version` (with a fallback), and the database supplies `created_at`.
- `public.handle_new_partner()` does not itself write consent events. The separate `on_auth_user_created` trigger calls `handle_new_customer()` on Auth user insert, so the actual signup trigger order and both signup pathways must be regression-tested before changing it.
- Customer and partner signup pages currently submit `terms_accepted` and `terms_version` in Auth user metadata. This branch adds a separate `privacy_version` value to both forms.

## Changes prepared on this branch

1. Customer signup metadata includes distinct Terms and Privacy version values (currently both `2026-11-11`, matching the existing published revision label).
2. Partner signup metadata includes the same separate values.
3. Draft SQL revokes direct authenticated INSERT on the consent table and updates the existing Auth trigger function to write separate `terms` and `privacy` events with database-generated timestamps.
4. Existing combined legacy events are retained; no historical split/backfill is proposed.

## Important security and legal limits

- Auth user metadata is user-controlled. It is used only as the submitted consent assertion, never for authorization, permissions, or entitlement decisions.
- The database trigger provides a server-side timestamp and prevents direct client insertion after the proposed grant change. It does not independently prove who clicked the checkbox, that the person had legal authority, or that the user actually read the linked policy.
- The trigger currently also provisions `customer_profiles`. Replacing it without confirming all Auth user creation flows could break signup or service-created users.
- Verify exact Terms/Privacy version identifiers and effective dates against the published policy contents before release.
- Existing legacy `terms_and_privacy` rows cannot be truthfully converted into separate historical Terms and Privacy events.
- The SQL is a review draft, not a migration. It has not been applied to Supabase.

## Required pre-release tests

- Customer signup with email confirmation enabled and disabled: exactly one Terms and one Privacy event.
- Partner signup with email confirmation enabled and disabled: exactly one Terms and one Privacy event.
- Missing/false consent assertion and missing version values: no silent incomplete acceptance; confirm expected signup failure behaviour.
- Existing non-customer/non-partner Auth creation flows remain unaffected.
- Auth trigger failure rolls back Auth user creation and dependent profile rows as expected.
- Authenticated direct INSERT is denied; own-user SELECT still works; cross-user SELECT denied.
- Authenticated UPDATE/DELETE denied; service role access remains appropriately restricted.
- Repeated signup/callback attempts do not create duplicate consent events.
- Confirm trigger function owner, fixed search_path, grants, RLS and Supabase advisors.

## Not changed

No production SQL, RLS, grants, Auth settings, Edge Functions, secrets, users, organisations or consent records were changed. No policy acceptance was fabricated or backfilled.
