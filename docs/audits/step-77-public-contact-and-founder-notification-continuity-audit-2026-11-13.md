# Step 77 — Public contact intake and founder notification continuity audit

Date: 2026-11-13
Branch: website/global-launch-readiness
Production project: ebltviniygljwwseplph
Scope: read-only verification of the public contact endpoint, Telegram retry worker, cron scheduling and notification outbox. No test enquiry was submitted and no production records or settings were changed.

## Contact form and deployed endpoint

- `contact.html` submits to the production `krim-public-contact-inquiry` Edge Function using the public publishable key.
- The form requires privacy consent, validates browser fields, applies a 20-second client timeout, and only displays a reference when the endpoint returns success.
- Deployed Edge Function `krim-public-contact-inquiry` is ACTIVE, version 20, with JWT verification disabled. This is consistent with a public enquiry endpoint; the handler validates request method, payload, consent, field lengths, and uses the service-role key only server-side.
- The endpoint checks the honeypot, checks IP throttling when the Cloudflare client-IP header is present, and calls database RPCs for email-rate-limited enquiry persistence and outbox creation.
- It then attempts to link the enquiry into the service-request qualification flow. Link failure is logged but does not invalidate the already persisted enquiry.
- The deployed version's source matches the reviewed repository implementation at the behavior level.

## Founder notification retry path

- Deployed `krim-notification-retry-worker` is ACTIVE, version 14, with JWT verification disabled but a dedicated cron secret required. It also supports authenticated platform-admin manual invocation.
- The worker processes enquiry and follow-up Telegram retry queues using claim/finish RPCs and records delivery results.
- Production `cron.job` contains active job 17, scheduled every five minutes, calling the retry worker using a Vault-decrypted secret reference. The secret value was not read or exposed.
- Recent `cron.job_run_details` rows for job 17 show repeated `succeeded` runs, including 2026-11-13 07:10 UTC. This confirms the scheduler successfully queued the HTTP request; it does not independently prove Telegram accepted a message.
- A read-only grouped query against `public.krim_notification_outbox` returned no rows. There is therefore no existing outbox sample available to demonstrate a successful or failed real notification in this check.
- A recent log query using the expected function-name filters returned no matching rows; this is inconclusive and is not treated as proof of zero invocations.

## Readiness result

**SOURCE + DEPLOYMENT + SCHEDULER CHECKS PASS; END-TO-END DELIVERY NOT YET PROVEN.**

The public enquiry path is deployed and has a configured retry worker scheduled every five minutes. However, a real enquiry submission, persisted outbox row, Telegram delivery acknowledgement and founder-side receipt have not been verified in this audit. Do not claim founder alerts are fully tested until that controlled end-to-end test is completed.

## Remaining controlled test

With owner approval, submit one clearly labeled test enquiry using a dedicated test identity and a non-sensitive message; verify its reference, database record, outbox state, Telegram provider message ID and founder-side receipt. Then confirm the test record is retained or removed only according to the approved retention process. Do not use fabricated customer details or trigger outreach to real prospects.

## Step 77 verdict

No production database, Edge Function, secret, cron schedule, website source, migration history, PR merge or deployment was changed.
