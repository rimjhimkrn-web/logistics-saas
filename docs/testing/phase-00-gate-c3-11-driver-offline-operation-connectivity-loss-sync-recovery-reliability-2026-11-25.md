# Gate C3.11 — Driver offline operation, connectivity loss, data synchronization and recovery reliability

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.11  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **FAIL / BLOCKED for operational offline capability claims; PARTIAL PASS for static shell caching and local tracking-stop safety.**

## 1. Scope and method

Read-only source inspection of:
- `service-worker.js`
- `public/offline.html`
- `public/app/offline-queue.html`
- `public/app/sync-status.html`
- `public/driver/offline-sync.html`
- `mobile/krim-driver/src/lib/locationTracking.ts`
- `mobile/krim-driver/package.json` and `app.json`
- `app/driver/module-08-live-tracking.html`
- `app/driver/module-09-exceptions-incidents.html`

This gate is source-level only. No browser offline simulation, device test, IndexedDB inspection, network throttling, mutation replay, RPC, database query or deployment was performed. The repository tree baseline is complete (not truncated).

## 2. Positive source controls

1. The service worker uses a versioned cache, removes older KRIM shell caches on activation, claims clients and caches a defined static asset shell.
2. It excludes auth pages, query-string routes, admin/control routes, API/auth/storage/functions endpoints and non-GET requests from its fetch cache handling. This reduces risk of caching authenticated or mutable API responses.
3. Offline navigation fallback is provided through `public/offline.html` when a request fails and no cached page is available.
4. Driver live-tracking browser page is explicitly read-only; it does not request browser GPS and says live collection is disabled.
5. Native driver GPS launch flag and consent-notice approval flag are both hard-disabled in `locationTracking.ts`.
6. Native tracking stop attempts to stop local collection before making a server request. On server failure it preserves identifiers for a later retry and reports that server stop remains unconfirmed. This is a useful fail-safe pattern, but runtime behavior was not tested.
7. Native GPS upload returns false on missing session, invalid accuracy or provider error; authorization/availability errors attempt to stop local tracking. GPS itself remains disabled by the launch gate.

## 3. Findings and release risks

### P1 — No implemented durable offline mutation queue was established
The service worker handles GET requests only. It has no Background Sync or Periodic Sync event handler, no request interception for POST/PATCH/DELETE, no IndexedDB queue, no replay scheduler, no per-action idempotency key, no conflict resolver and no durable acknowledgement state. The inspected native driver location module uses SecureStore for the current tracking assignment/session identifiers; it does not implement a general offline operational action queue for pickup, milestones, incident reports, ePOD, returns or other driver workflows.

**Impact:** When connectivity is lost, the source does not establish that driver actions can be safely captured and later synchronized. The user must not be told that queued actions will automatically sync.

### P1 — Offline queue screen presents fabricated operational records and a nonfunctional action
`public/app/offline-queue.html` hard-codes shipment `SHP-9921`, three pending ePOD items and 42 telemetry pings, and displays a “Sync Offline Queue Now” button without a handler or queue implementation in the page. These are not verified live records.

**Impact:** The screen can mislead users into believing actual customer shipment evidence or telemetry is pending and can be synchronized. It must be treated as a mockup, removed from operational navigation, or rebuilt from a real authenticated queue before release.

### P1 — Sync health screen displays unsupported success claims
`public/app/sync-status.html` hard-codes AP-SOUTH-1 and EU-CENTRAL-1 as synchronized, reports 14ms/42ms latency, shows zero unsynced items, and prints successful REST/WebSocket log lines. The inspected page has no live health query or telemetry binding.

**Impact:** Operators may believe replication is healthy when the values are static. No regional replica topology or latency claim is established by this screen.

### P1 — Offline fallback text claims automatic queued synchronization without a queue
`public/offline.html` states that queued telemetry actions and cached manifests will sync automatically upon reconnection, and describes local cache as active. The inspected service worker only caches static GET assets and contains no mutation queue or automatic replay.

**Impact:** Offline messaging overstates capability and may cause users to rely on unimplemented data persistence/recovery.

### P1 — Driver offline route is an alias to an unverified staging-named page
`public/driver/offline-sync.html` redirects to `app/driver/staging/page-09-live-tracking.html`. Prior C3.5/C3.6 findings establish that “staging” in a folder name is not an environment boundary, and that the GitHub Pages host resolves to Production Supabase by default unless its resolver is corrected. Deployment and runtime environment isolation of the destination remain unverified.

### P2 — Cache coverage does not include the inspected driver operating workspace
The service worker’s local shell list does not include the canonical `app/driver/*` routes or their page-specific scripts/styles. Its route allowlist contains only selected customer, enterprise, field and legal paths. The inspected driver pages therefore are not established as available offline from this worker. The root-relative asset paths also require deployment-base verification under the GitHub Pages project path.

### P2 — No data-integrity protocol for conflict, duplication or partial replay
No offline mutation schema or protocol was established for event UUID/idempotency, original device timestamp vs server receipt time, ordering/dependency constraints, assignment state revalidation, tenant ownership, payload versioning, attachment resumability, conflict resolution, retry backoff, poison-message quarantine, or audit trail. These are release prerequisites for safely replaying operational events.

### P2 — Local tracking-stop recovery is narrow and not end-to-end verified
The native tracking module preserves the assignment key when a server stop fails, which can support retry. However, it does not prove a durable generalized retry worker, visible pending-stop recovery state across app restarts, bounded retry/backoff, user notification or server-side reconciliation. GPS launch is disabled; Android/iOS real-device behavior is not tested.

### P2 — Native offline data protection and device lifecycle are unverified
No driver-specific offline database, encryption/key lifecycle, local data retention/deletion, device logout/wipe, shared-device protection, backup exclusion, attachment encryption or local queue access policy was established. SecureStore usage for two tracking identifiers does not establish protection for a future offline work queue.

## 4. Required remediation before release

1. Remove or clearly label the mock offline queue and static sync dashboard. Do not display example shipment IDs, pending counts, regional replica status or latency as live operational data.
2. Correct offline fallback copy to say only that cached static pages may be available and unsent actions are not guaranteed to persist. Provide an explicit “do not repeat / contact dispatch” instruction where duplicate operational action could be harmful.
3. Design a driver offline event queue with IndexedDB (web where supported) and an encrypted native local store (mobile), scoped to the authenticated user, organization, assignment and device.
4. Every queued action must include a cryptographically strong client-generated idempotency/event ID, schema version, entity/assignment/leg references, device event time, queue time, and explicit pending/attempting/accepted/rejected/conflict/dead-letter state. Never mark synced until server acknowledgement confirms the same event ID and payload hash.
5. Implement authenticated replay only after session and assignment revalidation; server-side idempotency; ordered/dependency-aware sync; bounded exponential backoff with jitter; network recovery; app restart recovery; cancellation/revocation handling; conflict resolution and operator-visible failure details.
6. Add attachment chunking/resume, integrity hash, private storage path binding, upload completion confirmation and evidence retention rules before claiming offline ePOD support.
7. Add a real queue and sync diagnostics screen driven by the queue/outbox and provider acknowledgement records. Clearly distinguish local saved, upload pending, server accepted, business-approved and customer-visible states.
8. Expand static shell caching only after a route-by-route data classification review. Never cache authenticated API responses, private shipment/evidence data or signed URLs in the shared shell cache.
9. Implement secure local storage lifecycle, logout/device revocation cleanup, shared-device protections and explicit offline data retention.
10. Execute isolated Staging browser and native-device tests: airplane mode before/during/after each action; process kill/restart; OS background/termination; clock skew; duplicate replay; out-of-order events; assignment revoked while offline; expired session; partial file upload; storage quota; corrupted queue; app upgrade/schema migration; server timeout; retry storm; and eventual recovery. No Production load or real customer records.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Static shell cache/version cleanup | SOURCE PASS | Versioned cache and old KRIM cache cleanup exist. |
| Auth/API/private mutation cache exclusion | SOURCE PASS | Auth routes, query routes, API endpoints and non-GET requests bypass cache handling. |
| Driver route offline availability | BLOCKED | Driver routes/scripts are not in the inspected shell cache allowlist. |
| Durable driver offline mutation queue | FAIL | No queue store, replay worker or Background Sync implementation established. |
| Offline ePOD / milestone / incident persistence | BLOCKED | No offline mutation path proven. |
| Offline queue UI truthfulness | FAIL | Hard-coded shipment and pending records; sync button has no handler. |
| Sync status truthfulness | FAIL | Static regional, latency, zero-queue and success log claims. |
| Offline fallback copy | FAIL | Claims automatic queued sync without supporting queue. |
| Native GPS stop local-first behavior | SOURCE PARTIAL PASS | Local stop precedes server call; pending identifiers preserved on failure. GPS launch remains disabled. |
| Native GPS real-device/offline behavior | NOT TESTED | Android/iOS device tests not run. |
| Conflict/idempotency/ordered replay | FAIL / NOT IMPLEMENTED IN REVIEWED PATHS | No durable replay protocol found in inspected files. |
| Encryption/retention/device logout for offline queue | NOT TESTED | No general offline store established. |
| Browser/device/network recovery tests | NOT TESTED | Await Staging isolation and implementation. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or notification was changed or invoked.
- No offline action was queued or replayed.
- No test user or device was created.
- No real shipment, ePOD, GPS or telemetry data was transmitted.
- No production load or destructive test was run.
- This artifact is documentation-only on the isolated QA branch.

**Gate C3.11 result: FAIL / BLOCKED for offline operational capability.** Keep offline dispatch, offline ePOD, automatic synchronization, live sync-health and offline driver workflow claims on **NO-GO** until the queue, truthful UI, security protocol and isolated recovery tests are implemented and verified.
