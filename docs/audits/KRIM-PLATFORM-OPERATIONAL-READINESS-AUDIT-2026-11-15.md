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
The production schema includes `krim_data_retention_policies`, `krim_customer_consents`, `krim_user_consent_events` and `krim_driver_tracking_sessions`, but the retention-policy table currently has **0 rows**, customer-consent records are **0**, user-consent events are **0**, and driver tracking sessions are **0**. The only consent-like GPS record structure currently available is the per-trip tracking session with a consent version and timestamps. No public/private SQL function with a retention, erasure or purge name was found in the inspected public function catalogue. The presence of a policy table is not an approved retention schedule or an automated deletion control.

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

## 7. Legal and privacy work requiring qualified review

- India DPDP Act 2023 and DPDP Rules 2025 have staggered commencement dates. The Gazette notification dated 13 November 2025 schedules the main processing provisions for 18 months after publication (approximately 13 May 2027); other provisions commenced earlier or on the one-year date. Prepare now; obtain counsel's advice on the provisions already in force and the transition timeline.
- Review privacy notice, terms, cookie/analytics disclosures, data inventory, lawful basis/consent, retention/deletion, grievance/contact route, processors/subprocessors, security safeguards, incident/breach response and cross-border data flows.
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
