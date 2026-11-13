# Step 26 — Schema export execution gate and staging baseline scope

Date: 2026-11-13
Branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Workflow execution check

Queried GitHub Actions runs for branch `website/global-launch-readiness` and filtered for `.github/workflows/krim-schema-export.yml`. No run was returned. Therefore:
- No export workflow execution is evidenced.
- No encrypted schema artifact or checksum is available to verify.
- The two required repository secrets have not been verified.
- No production dump or staging import has occurred.

The latest visible PR checks at this point include successful static link audit and production smoke-check runs for commit `e6d1f652d105cf3f640e0e40fc51de3b87382eb7`. These are website/code checks only; they do not validate the schema export workflow or database lifecycle.

## Staging baseline scope prepared

Before staging can be used for lifecycle testing, the baseline process must cover more than application table DDL. The current workflow exports selected application schemas only. The staging bootstrap must separately account for:

1. PostgreSQL extensions and versions, including compatibility differences between production and staging.
2. Roles, grants, default privileges, ownership, and Supabase-managed roles (recreate only what is supported and safe).
3. Auth configuration and provider settings, with staging-only test users and no production identities.
4. Storage buckets, object policies, and storage configuration; no production objects or documents.
5. Edge Functions and their environment variables, using staging-only credentials and outbound notifications disabled.
6. Database cron, queues, realtime publication settings, webhooks, and external integrations, recreated only after review.
7. RLS policies, grants, functions, triggers, constraints, indexes, and custom types.
8. Supabase project settings, URL allowlists, redirect URLs, SMTP, rate limits, and MFA configuration.
9. Synthetic test fixtures only, with no real customer, partner, shipment, payment, identity, or financial records.

## Safety decision

Do not import an application-schema dump directly into the currently empty staging project. First verify the dump, reconcile extensions and managed objects, review grants/ownership and all security-definer routines, and produce a staged bootstrap plan. The production/staging Postgres minor versions differ (production 17.6; staging 17.11), so extension and dump/restore compatibility must be checked.

## Actions and non-actions

- GitHub Actions run list checked; no schema-export run found.
- No artifact downloaded because none is evidenced.
- No secrets API or secret values accessed.
- No database query beyond the earlier production catalog inventory.
- No staging or production changes.
- No migration, data copy, provider action, deployment, or merge.

## Required external action

Repository administrator must confirm the two Actions secrets in GitHub Settings → Secrets and variables → Actions, then manually run the workflow from the `website/global-launch-readiness` branch. Keep both values private; do not paste them into chat. After a successful run, verify artifact and checksum, decrypt only in a secured environment, and review the dump before preparing any staging bootstrap.

## Result

Step 26 completed as an execution-status check and staging baseline scope review. The schema export remains the critical blocker. Staging is not ready for E2E tests and no launch-readiness claim is made.
