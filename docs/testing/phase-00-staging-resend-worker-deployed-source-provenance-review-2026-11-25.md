# Phase 00 — Staging Resend worker deployed-source provenance review

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Function: `krim-resend-email-worker`  
Project: Staging `qrpcivhdxobiaofppbkl`

## Deployed artifact identity

Read-only function retrieval confirmed:
- Status: ACTIVE
- Version: 1
- verify_jwt: false
- Entrypoint: `index.ts`
- Deployed source SHA-256 (Supabase deployment metadata): `fdb9b23d22ac98b7776dc3358bcdc2fd61d2da0a6826fd7b6cfeb686c7d00712`
- Source was retrieved successfully and reviewed in full.

Prior repository inventory found no matching `supabase/functions/krim-resend-email-worker/index.ts` source in the QA branch. The deployed artifact therefore has no committed source provenance in the reviewed branch. This report records its deployment identity and findings; it does not silently adopt or deploy it.

## Critical isolation findings

The retrieved worker:
1. Accepts POST only and checks `x-krim-cron-secret` against `KRIM_NOTIFICATION_CRON_SECRET`; the expected secret must be at least 32 characters.
2. Does not validate that `SUPABASE_URL` points to the intended Staging project.
3. Does not enforce a recipient allowlist or test sink.
4. Has no dry-run mode. Once queue claim succeeds, it calls `https://api.resend.com/emails`.
5. Uses service-role credentials to claim queue records and read Auth user email addresses.
6. Uses a configured sender and a configurable HTTPS application base URL; the code validates HTTPS and absence of URL credentials, but does not pin the allowed host.
7. Uses the outbox idempotency key, with a fallback derived from outbox ID.
8. Finishes a claimed record even when the recipient is missing/unconfirmed, treating that condition as a failure and consuming retry attempts.
9. Records provider acceptance as sent; no delivery callback is implemented in this worker.

## Risk assessment

This is a real email-sending worker, not a safe synthetic test harness. A mistaken invocation against the Staging project could send messages to actual partner applicant addresses in its queue. The lack of a project assertion and recipient sink/allowlist makes accidental cross-environment or real-recipient delivery insufficiently guarded.

The cron-secret check is a useful authentication barrier, but it does not replace environment assertion, recipient isolation, dry-run, or provenance controls.

## Required actions before any test invocation

- Completed: preserved the exact retrieved source under `supabase/functions/krim-resend-email-worker/index.ts` on the QA branch and verified byte-for-byte equality with the deployed Staging version 1. This is source provenance only; it was not deployed.
- Add a project-ref assertion against the known Staging project.
- Add a mandatory recipient allowlist and sink-only mode; reject all non-allowlisted addresses before queue claim.
- Add a dry-run that does not claim queue records and cannot call Resend.
- Ensure all configuration failures fail closed before queue claim.
- Add tests with mocked provider and RPC clients for wrong project, wrong/missing secret, disallowed recipient, empty queue, malformed payload, duplicate run, provider acceptance, provider rejection, timeout and finish-RPC failure.
- Introduce stale-claim recovery and provider callback ingestion before production-grade operation.
- Verify deployment source hash after any future controlled deployment.

## Evidence boundary

The deployed source and metadata were retrieved and statically reviewed. No Edge Function invocation, queue claim, Auth lookup, email API call, or database write was performed. No secrets were read or exposed. Production and Staging remained unchanged.
