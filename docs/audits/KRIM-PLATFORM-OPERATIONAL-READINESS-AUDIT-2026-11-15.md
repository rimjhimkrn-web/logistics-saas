# KRIM Platform Operational Readiness Audit — 15 November 2026

Status: **IN PROGRESS — NOT APPROVED FOR UNRESTRICTED COMMERCIAL OPERATIONS**
Project: `ebltviniygljwwseplph` (production Supabase)
Repository: `rimjhimkrn-web/logistics-saas`
Audit method: live read-only production database queries, Supabase advisors, repository source/configuration review, and deployed Edge Function metadata. No synthetic shipment, driver, payment, or customer records were created for this audit.

## 1. Executive conclusion

KRIM has substantial platform foundations, including customer/partner/driver workspaces, a Supabase workflow backend, three Expo mobile applications, shipment tracking, and partner verification/capacity workflows. These are **not equivalent to an operational logistics network**.

The current production snapshot shows no verified partner organization, no active verified partner capability, no approved rate card, no accepted shipment-partner assignment, no driver assignment, and no GPS events. Therefore KRIM cannot yet demonstrate end-to-end fulfilment of a real shipment. Keep booking, provider availability, live GPS and commercial promises fail-closed until the relevant real-world evidence and tests exist.

## 2. Verified production data snapshot

| Measure | Observed count | Operational meaning |
|---|---:|---|
| Organizations | 14 | Accounts/organizations exist; not evidence of operating partners |
| Active organizations | 14 | Active status alone is not partner verification |
| Active verified partner organizations | 0 | No verified partner currently evidenced |
| Partner verification cases | 1 | Review process has begun |
| Approved partner verification cases | 0 | No approved case evidenced |
| Partner capabilities | 1 | One capability record exists |
| Active, verified partner capabilities | 0 | No approved active capability evidenced |
| Rate cards | 1 | One rate-card record exists |
| Approved/active rate cards | 0 | No approved commercial tariff evidenced |
| Shipments | 18 | Shipment rows exist; their real/test provenance must be confirmed before treating as live demand |
| Shipment-partner assignments | 0 | No provider assignment evidenced |
| Accepted/active/in-progress partner assignments | 0 | No accepted fulfilment evidenced |
| Driver assignments | 0 | No driver dispatch evidenced |
| Tracking events | 1 | One event exists |
| GPS tracking events | 0 | No GPS telemetry exists |
| Driver tracking sessions | 0 | No location-consent session exists |
| Active countries / markets | 6 / 6 | Catalogue/market flags do not prove legal or partner coverage |

**Go-live implication:** do not claim a route is serviceable, quote-ready, bookable or confirmed merely because a country/market is marked active. Require current partner verification, exact route/service capability, available capacity, applicable compliance evidence, approved commercial terms and partner acceptance.

## 3. GPS and mobile tracking

### Existing implementation found
- KRIM has three separate Expo applications: Customer, Partner and Driver.
- The Driver app already contains native `expo-location` / `expo-task-manager` foreground and Android background tracking code.
- Driver tracking uses SecureStore for local assignment/session identifiers and a server-recorded consent session.
- Server-side checks bind updates to the authenticated driver, verified driver profile/licence, active organization membership, in-transit driver assignment, linked partner assignment, matching shipment leg and active tracking session.
- The public shipment tracking Edge Function returns a latest GPS point only when one exists and labels freshness as live/recent/stale.
- Both the native app source gate and the server-side Edge Function gate currently keep GPS collection disabled pending approval. The server requires `KRIM_GPS_TRACKING_ENABLED=true` and the exact approved legal version `2026-11-15-v1`. **Do not set these flags yet.**
- Production has 0 driver assignments, 0 tracking sessions and 0 GPS events, so a real driver-to-customer GPS test is not possible yet.

### Retention and consent evidence check
The production schema includes `krim_data_retention_policies`, `krim_customer_consents`, `krim_user_consent_events` and `krim_driver_tracking_sessions`, but the retention-policy table currently has **0 rows**, customer-consent records are **0**, user-consent events are **0**, and driver tracking sessions are **0**. The only consent-like GPS record structure currently available is the per-trip tracking session with a consent version and timestamps; the table does not itself archive the exact notice text/hash shown to the driver. No public SQL function with a retention, erasure or purge name was found in the inspected function catalogue. The presence of a policy table is not an approved retention schedule or an automated deletion control. Archive each exact consent notice version immutably and bind the session's version to that archived text before launch.

### Required before GPS launch
1. Approve the exact purpose, who can view a driver's location, the trip-only scope, consent language and how consent can be withdrawn.
2. Approve a retention period and deletion/erasure workflow, including exceptions for disputes, claims, tax/legal holds and incident investigations.
3. Define access logging, support access, breach response, data-subject request handling and vendor/subprocessor disclosures.
4. Review India DPDP commencement and obligations with qualified counsel; review each other corridor before cross-border launch.
5. Review Google Play background-location and foreground-service declarations. Background permission is not automatically approved because the app has a GPS feature.
6. Test on physical Android devices, including permission denied, approximate location, background permission denied, screen lock, battery saver, app swipe-away, force-stop, offline/recovery, stale positions and explicit stop.
7. Test customer token access, organization isolation, freshness labels, consent/session stop and unauthorized user denial end-to-end.

Until these gates are complete, keep GPS disabled. No paid GPS vendor is required for the initial design: smartphone GPS + native driver app + Supabase + a map display is sufficient. A browser-only page is not a reliable substitute for Android background tracking.

## 4. Supabase security and database observations

- No RLS-disabled tables were found in the `public` schema.
- One RLS-disabled table was found in the non-exposed `private` schema: `private.krim_driver_invitations`; current checks show no SELECT privilege for `anon` or `authenticated`. Review its intended service-only access model, but do not add public policies by default.
- Security advisor: 26 RLS-enabled tables have no policies. This can be intentional for service-only/internal tables; each finding needs an explicit owner/access-model decision. Do not blanket-add policies.
- Public schema: 308 SECURITY DEFINER functions; 127 are executable by `authenticated`; none of those functions are executable by `anon`; all inspected SECURITY DEFINER functions have a fixed search_path. The advisor warning is a function-by-function review queue, not proof that all 127 are exploitable. Verify identity, tenant/object ownership, permission checks, validation and audit behavior before changing grants.
- Supabase Auth leaked-password protection is disabled. Current Supabase documentation says this feature is available on Pro plan and above; if KRIM remains on the Free plan, do not upgrade solely for this toggle yet. Apply strong password length/complexity, verified email, rate limiting and MFA controls where available, then revisit the feature when revenue justifies Pro. Reference: https://supabase.com/docs/guides/auth/password-security.
- Performance advisor reports 701 unused indexes. With a low-traffic/early-stage database this is not proof of waste. Do not drop indexes without workload and query-plan evidence.
- Health advisor returned no findings at this snapshot.

### Migration history drift — critical change-control blocker
The repository contains 272 SQL migration files, while the production migration ledger contains 434 entries. A direct filename/version comparison does not reconcile the two histories. This may reflect historical migration renaming/squashing or out-of-band application, but it means the repository cannot currently be assumed to reproduce production exactly.

**Rule:** no further production DDL or bulk schema changes until the complete migration history is reconciled against the live schema, duplicate timestamps and applied versions are resolved, and a safe staging/restore plan exists. Keep using read-only audits and narrowly scoped Edge Function/source changes only where safe.

## 5. Quote-to-assignment state integrity — P0 review blocker

Live database inspection found a legacy but authenticated-executable award path:
- `krim_award_partner_quote` creates a partner assignment with status `offered`, but also transitions the shipment to `confirmed` immediately.
- `krim_award_partner_quote_for_checkout` calls that function and creates a customer quote already marked `accepted`, while the partner assignment is still only `offered`.
- The canonical customer quote acceptance RPC `krim_accept_global_quote` correctly requires an accepted partner quote and matching accepted assignment before confirming a shipment.
- The partner response RPC `krim_respond_to_partner_assignment` changes an offered assignment to accepted/rejected and commits capacity; the rejection trigger cancels the linked accepted customer quote. It does not itself transition the shipment to confirmed on partner acceptance.

This leaves two different quote-award semantics in production. The current customer quote/bid HTML workflows reviewed call `krim_accept_global_quote`; no call to the two legacy award functions was found among the 38 quote/bid HTML pages inspected. However, both legacy award functions remain executable by authenticated users and can bypass the canonical state rule.

**Required before public booking:** reconcile migration history, then either revoke the unused legacy award RPCs or correct the flow so a customer award creates an `offered` assignment and the shipment becomes `confirmed` only after the verified partner accepts that exact assignment. Add regression tests for offer, accept, reject, timeout, re-award and duplicate retries. Do not patch this through an untracked production SQL change while migration history remains unreconciled.

## 5. Mobile release engineering

- Customer, Partner and Driver Expo apps are present.
- The mobile validation workflow runs a three-app matrix and checks Expo compatibility/configuration, TypeScript and Android export.
- The internal APK workflow uses EAS and requires the repository's `EXPO_TOKEN` secret. An EAS build may consume hosted build quota; do not trigger a new cloud build without checking the available plan/quota.
- Committed `package-lock.json` files now exist for all three apps, and the validation workflow uses `npm ci`.
- On 15 November 2026, the Customer, Partner and Driver app jobs all passed dependency installation, Expo compatibility/configuration checks, TypeScript checks and Android exports. This is CI build evidence, not physical-device acceptance.
- A GitHub Actions job is currently building an installable KRIM Driver Android debug APK using Gradle; this audit snapshot does not yet count that build as passed.
- Prior mobile audit recorded owner-confirmed installation of preview APKs, but this audit did not re-test those devices.
- Internal APK success is not public store approval or production acceptance.

Required: generate and commit app-local lockfiles, switch CI to `npm ci`, pin build tooling, validate app configuration and permissions, test all three apps on real devices, and separate internal preview from production AAB/store workflows.

## 6. Commercial and fulfilment release blockers

1. **Partner supply:** obtain at least one independently verified operating partner with approved evidence, exact service/corridor capability, current capacity and a named operational contact.
2. **Commercial terms:** approve the partner's rate card/quote terms, validity, exclusions, cancellation and dispute handling.
3. **Booking:** prove a customer request cannot be represented as confirmed until a specific provider has accepted the exact job.
4. **Dispatch:** prove driver/vehicle eligibility, licence/document validity, organization membership, trip state and shipment-leg binding.
5. **Execution:** test pickup, milestones, exceptions, tracking consent, POD evidence and independent verification.
6. **Finance:** test invoice, fee, payment, refund, reconciliation and ledger behavior in a safe sandbox. Keep customer freight payments separate from KRIM's own referral/coordination income and SaaS revenue.
7. **Notifications:** test Telegram/email delivery, retry, duplicate suppression, bounce/failure handling and audit trails.
8. **Support:** establish real support ownership, escalation windows, claims/disputes, incident response and customer/partner communications.

The current lean referral/coordination model still needs a written agreement and CA review. Do not assume it is GST-exempt. Customers should contract with and pay the service partner directly if that remains the chosen model; KRIM must not accidentally imply it is the carrier or collect freight consideration contrary to its contracts and tax advice.

### Partner-direct payment safety snapshot
- The current customer payment guidance page states that customers contract with and pay the selected provider directly; KRIM does not collect freight charges or settle partner funds.
- The Razorpay order-creation Edge Function has a fail-closed `KRIM_FREIGHT_COLLECTION_ENABLED=true` plus exact approval-version gate. The payment-verification function also blocks verification of unpaid KRIM-collected freight orders unless that approval gate is deliberately enabled; same-payment retries for already-paid legacy records remain available.
- The production `payment_orders` table currently contains **5 legacy created/unpaid Razorpay orders** (created 25–26 September 2026; INR; total stored amount 14,000,000 paise) and **1 legacy paid order** (35,00,000 paise). None of these six rows is bound to a KRIM quote or partner quote. The table does not record the Razorpay test/live key mode for these legacy rows.
- The five unpaid legacy orders must be reconciled in the Razorpay dashboard before public launch: establish test vs live mode, confirm whether any order links remain usable, and cancel/expire them with the provider if possible. Reconcile the one paid legacy order to its actual provider receipt and internal ledger. Do not enable KRIM freight collection as part of the initial partner-direct model.

## 7. Legal and privacy work requiring qualified review

- India DPDP Act 2023 and DPDP Rules 2025 have staggered commencement dates. The Gazette notification dated 13 November 2025 schedules the main processing provisions for 18 months after publication (approximately 13 May 2027); other provisions commenced earlier or on the one-year date. Prepare now; obtain counsel's advice on the provisions already in force and the transition timeline.
- Review privacy notice, terms, cookie/analytics disclosures, data inventory, lawful basis/consent, retention/deletion, grievance/contact route, processors/subprocessors, security safeguards, incident/breach response and cross-border data flows. The production Supabase database project is currently in `ap-northeast-1` (Tokyo, Japan); document this cross-border processing and have counsel review it.
- Review partner/customer contracts, marketplace role, service liability, claims, refunds, insurance representations, transport documentation, GST/invoicing and payment handling with an Indian CA/lawyer.
- Review Google Play and Apple location/data disclosures before store distribution.
- Do not claim licenses, certifications, insurance, route coverage or global availability unless documented and current.

## 8. Recommended implementation sequence

### P0 — Reconcile and protect the production foundation
- Reconcile migration history before schema changes.
- Complete SECURITY DEFINER and no-policy RLS inventories; test both allowed and denied access.
- Enable leaked-password protection.
- Confirm backup/restore and incident recovery procedures.
- Keep all booking, payment, GPS and market activation gates fail-closed until verified.

### P0 — Establish one real operating corridor
- Select one India domestic pilot corridor.
- Verify one anchor partner and its evidence/capability/capacity.
- Approve rate/quote terms and operating responsibility.
- Complete one synthetic end-to-end customer → partner → dispatch → driver → POD → customer test before live freight.

### P0 — Complete GPS privacy and physical-device acceptance
- Approve location notice, consent, retention, deletion and access rules.
- Keep server and app launch gates OFF until written approval.
- Run Android device matrix and customer freshness/access tests.

### P1 — Make builds and tests reproducible
- Generate app lockfiles and use `npm ci`.
- Run all three app validation jobs.
- Establish synthetic customer/partner/driver accounts with no real customer or employee data.
- Add automated negative authorization and idempotency tests.

### P1 — Complete operational support and communication tests
- Verify founder alerts, customer/partner notifications, support intake and escalation.
- Test retries, duplicate events, delivery failures and audit logs.

### P1 — Complete CA/legal review
- Approve initial contracts, terms, privacy, GST/invoice model, refunds and service liability.
- Keep paid checkout and international corridors disabled until separately approved.

## 9. Acceptance standard

A workflow is complete only when a synthetic or explicitly authorized real test user can initiate it in the deployed UI; server-side permissions and tenant boundaries are enforced; the correct records and audit events are written exactly once; notifications are delivered or safely retried; failure/denial cases are tested; the final state is visible only to authorized roles; and the workflow is repeated on the deployed mobile/web build.

**This audit is a factual readiness snapshot, not legal advice, security certification, app-store approval, proof of live GPS, or approval for unrestricted commercial logistics operations.**

## 10. Post-audit implementation update — 15 November 2026

This addendum records changes made after the initial read-only snapshot. It does not waive the release gates above.

### Implemented safeguards and code changes
- **Driver GPS is fail-closed.** The native Driver app source has `DRIVER_GPS_LAUNCH_ENABLED = false`; the browser Page 54 GPS control is also disabled. The deployed `krim-driver-tracking-session` and `krim-driver-gps-update` Edge Functions require both `KRIM_GPS_TRACKING_ENABLED=true` and `KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION=2026-11-15-v1`. The stop-session action remains available. Do not set these values until the notice, retention, deletion, access and legal reviews are signed off.
- The Driver app now stops local tracking on sign-out/session loss and clears tracking state when the launch gate is off. Android foreground-service/background-location permissions are declared in the native app config. The app contains background tracking code, but it has not passed physical-device acceptance.
- The customer tracking endpoint/page now labels GPS freshness (live/recent/stale) from the recorded event timestamp. A tracking reference is a bearer credential; the Privacy Notice now tells users to keep it private.
- The Privacy Notice now describes GPS fields/purpose and the actual Supabase project region. The interim Data Retention page no longer promises unverified seven-year/90-day periods, WORM storage, AES-256 archival or NIST 800-88 erasure. No fixed raw-GPS retention period or automated purge has been verified; GPS remains gated.
- **Payment collection is fail-closed.** The INR Razorpay capability registry currently has checkout disabled and merchant eligibility, settlement, refund and FX support are not verified. The deployed `create-global-razorpay-order` function additionally requires `KRIM_FREIGHT_COLLECTION_ENABLED=true` and `KRIM_FREIGHT_COLLECTION_APPROVAL_VERSION=2026-11-15-v1`. This endpoint creates a full-quote order on KRIM's merchant account; its Razorpay order payload contains no Route transfer instruction. A 10/90 accounting-ledger allocation is not proof of an actual partner payout. This conflicts with the current partner-direct freight-payment model; do not enable it without CA/legal and settlement approval. Existing Razorpay verification/webhook paths are retained for historical reconciliation. Cashfree create/verify/webhook endpoints return HTTP 410.
- A narrow forward-only migration `20261115063039_require_partner_assignment_before_global_quote_acceptance` was applied and the matching SQL file is now committed. It prevents the legacy `krim_accept_global_quote` path from accepting a customer quote without an accepted partner quote, matching accepted partner assignment, active verified partner and current capability. This single migration does **not** reconcile the broader migration-history divergence. No further production DDL should be applied until that reconciliation is complete.
- Historical data review found 6 accepted customer quotes with no linked partner quote and 6 confirmed shipments but no shipment-partner assignments. Treat these as legacy/test or incomplete records until their provenance is confirmed; do not present them as fulfilled/partner-confirmed bookings.
- Direct public-schema catalog checks found 21 RLS-enabled tables with no policies and no privileges for anon/authenticated roles; the Supabase advisor reports 26 no-policy findings across its broader scan. No public-schema table with RLS disabled was found. The five deployed Edge Functions with JWT verification disabled were reviewed at source level: public shipment tracking uses a 32-hex (128-bit) token; Razorpay webhook validates its signature; public contact inquiry has honeypot/size/email-rate controls; notification retry worker requires an internal secret or admin authorization; the Cashfree webhook is retired (410). This is source review, not penetration testing.
- The partner Services & Capabilities workspace was checked against the live schema: it calls the authenticated `krim_partner_submit_service_capability_v2` RPC, uploads 1–5 evidence files to private storage and creates an inactive pending-review capability. A stale paragraph incorrectly claimed the form was local-only/no RPC; that copy has been corrected. The live authenticated submission still needs a partner test account and real evidence.
- The notification retry cron is scheduled every five minutes. The notification outbox was empty at audit time; no real Telegram delivery test was performed. One HTTP timeout was observed in the recent cron response history, followed by successful responses.
- All three mobile app lockfiles are now committed and the validation workflow uses `npm ci`. Customer, Partner and Driver validation, TypeScript checks and Android exports passed. A free installable Driver debug APK build is running separately; debug APK installation is not a Play Store release or device acceptance.
- The public site smoke check and static link audit passed on commit `69895b1e8f2454c9806754df1d70f06df945de85`; GitHub Pages deployment was still pending at the time of this addendum.

### Updated production facts and unresolved gates
- The live migration ledger now contains 437 entries versus 275 repository SQL migration files. A fresh metadata-only comparison found 67 exact version matches, 208 repository-only versions, 370 production-only versions and 212 descriptive names shared across the two inventories. Several 15 November migrations share descriptive names but use different version timestamps; only the quote-acceptance guard above is an exact new version match. This does not establish SQL-body equivalence. Do not replay, reset, squash, mark-as-applied or add more production DDL until the full crosswalk and schema baseline are independently reviewed.
- No active verified partner capability, approved capacity resource, partner assignment, driver assignment, warehouse facility, customs assignment, GPS event or GPS session is present. The 6 active market flags are catalogue state, not proof of service coverage.
- Five historical Razorpay payment orders are in `created` state and one is `paid`; reconcile every record with the Razorpay dashboard, bank settlement and the accounting ledger before any new payment flow. Do not assume the paid record represents a completed partner payout.
- The current Supabase project region is Tokyo, Japan. The India-to-Japan data-processing arrangement and any later corridor-specific transfers require documented legal review.
- Supabase Auth leaked-password protection is not included on the current Free plan. Do not mark this control complete unless the plan changes and the setting is enabled; maintain the strongest available password/email/MFA/rate-limit controls meanwhile.
- **Critical partner-direct readiness mismatch:** the live `krim_internal_evaluate_shipment_readiness` function derives `payment_status` from KRIM payment records and returns blocked when a non-draft/requested shipment has no KRIM-paid order. The `krim_shipment_readiness_enforcement` BEFORE UPDATE trigger invokes that evaluator before transitions to `confirmed`, `assigned` or `dispatched`. This conflicts with the partner-direct launch model and can prevent a new shipment from reaching confirmed/dispatch even though KRIM correctly refuses to collect freight funds. The quote-result route now redirects to direct-payment guidance and the shipment-confirmation page is historical-only, but the backend readiness rule and a new direct-booking confirmation workflow must be reconciled before live bookings. Do not create fake paid orders or bypass this trigger; resolve it only after the migration crosswalk is complete. A draft migration `20261115090000_partner_direct_shipment_readiness.sql` now proposes the `partner_direct` readiness state and extends the `chk_readiness_payment` constraint, but it has **not** been applied to production. Source-level smoke checks do not prove deployment or live behavior. Customer quote-acceptance controls in both the Customer OS and shipper quote-approval pages are now fail-closed until this migration is reconciled, deployed and tested; quote review remains available, but the UI will not submit a booking acceptance that the live readiness gate cannot complete.
- The current legal form is a sole proprietorship. Obtain written Indian legal/CA advice on the e-commerce marketplace classification and company-form requirement, Carriage by Road Act exposure, GST treatment of referral/coordination fees, partner/customer contracts, claims/liability, insurance representations and cross-border data processing before commercial launch.
- A real pilot still requires one independently verified registered-business partner, a specific approved India corridor, current capability/capacity, an approved rate/quote, a named driver/vehicle, and an end-to-end acceptance test. No page count or static test can substitute for that operating evidence.

**Updated acceptance boundary:** KRIM remains **NOT APPROVED FOR UNRESTRICTED COMMERCIAL OPERATIONS**. Booking, freight collection and GPS must remain fail-closed until their specific gates are approved and tested.


## 11. Verification delta — later production checks on 15 November 2026

This section supersedes only the specific status items noted below. It does not certify commercial readiness or waive the acceptance gates above.

### Confirmed later backend changes

- The production migration ledger now contains **443** entries while the repository contains **281** SQL migration files. The histories remain materially divergent. The later applied migrations do not establish a complete migration crosswalk. Continue to prohibit ad-hoc schema changes, migration replay, resets, squashing or marking migrations as applied until the production schema and migration history are reconciled.
- The deployed `krim_internal_evaluate_shipment_readiness(bigint)` now records `payment_status='partner_direct'` for non-draft/requested shipments and `krim_freight_collection_required=false`. This removes the previously observed KRIM-paid-order dependency at the readiness-function source level. It has **not** been proven by a real end-to-end customer → accepted partner → dispatch transition.
- The authenticated `krim_get_shipment_tracking(text)` RPC is present in production. It checks customer-organization or partner-assignment access; returns GPS only for a currently active consent session tied to a verified driver, active membership, in-transit driver assignment and matching partner shipment leg; and excludes GPS points from the generic event history.
- The private idle-session expiry function is deployed and its pg_cron job is active on a five-minute schedule. It marks sessions stopped after 15 minutes without a GPS event (or after 15 minutes from session start when no first point was received). At this check, `cron.job_run_details` contained no recorded executions for this job; therefore the schedule is configured, but successful scheduled execution has not yet been evidenced.
- GPS remains deliberately fail-closed: the native app and server-side approval constants are false, and the legal approval version is not authorized. No location data is collected while the gate remains closed.

### Critical remaining shipment-state defect

The deployed legacy functions `krim_award_partner_quote(bigint)` and `krim_award_partner_quote_for_checkout(bigint,timestamptz)` remain executable by the `authenticated` role. The first creates a partner assignment with status `offered` and, when the shipment is `quoted`, calls the privileged transition function to move the shipment to `confirmed` before the partner accepts. The second calls the first and inserts a customer quote already marked `accepted` while the partner assignment may still be `offered`.

The canonical `krim_accept_global_quote` path now requires an accepted partner quote and matching accepted assignment, but that does **not** neutralize the separate legacy award RPCs. This is a P0 state-integrity bypass. The legacy functions must be retired or corrected and their authenticated grants removed after the migration crosswalk and caller inventory are independently reviewed. Do not attempt to patch this through an untracked production SQL change.

### Updated production supply and tracking snapshot

A later read-only check returned:

| Measure | Current observation |
|---|---:|
| Organizations | 14 |
| Verified partner organizations | 0 |
| Partner capabilities | 1 pending |
| Capacity resources | 0 |
| Approved/active rate cards | 0 (one pricing rate-card draft) |
| Accepted/active partner assignments | 0 |
| Driver assignments | 0 |
| GPS tracking events | 0 |
| Active driver tracking sessions | 0 |
| Data-retention policy rows | 0 |
| Customer consent records | 0 |
| User consent events | 0 |

These counts confirm that KRIM still has no evidenced live fulfilment network or real GPS operation. Do not treat historical shipment/quote rows or active market catalogue flags as live service capacity.

### Later code validation

- Production smoke checks, static link audit and GitHub Pages deployment all passed on commit `46b30597e77884306715f257f9dff34ca2ce4582`.
- The three Expo app validation jobs (Customer, Partner, Driver) passed on commit `f25b71171cf4cd6b3e993e8355d1634dfc828047`. This includes dependency installation, Expo configuration checks, TypeScript validation and Android export; it is not physical-device acceptance.
- The installable Driver debug APK build was still running at the time of this update. No APK installation or physical-device GPS acceptance is claimed.

**Updated release decision:** KRIM remains **NOT APPROVED FOR UNRESTRICTED COMMERCIAL OPERATIONS**. The next technical P0 is the legacy partner-award RPC state bypass after migration reconciliation. The next real-world P0 is onboarding and independently verifying one anchor operating partner on one approved India corridor. GPS, payment collection and public booking remain gated until their separate legal, operational and end-to-end acceptance criteria are met.
