# KRIM partner evidence RPC live catalog comparison — 2026-11-24

## Scope
Read-only SQL comparison of the partner evidence submission RPCs in production project `ebltviniygljwwseplph` and staging project `qrpcivhdxobiaofppbkl`. Compared function identity/signature, SECURITY DEFINER flag, normalized definition hash and effective EXECUTE privileges for anon, authenticated and service_role. Also inspected the relevant function bodies. No database changes or test submissions were performed.

## Effective grants and definition parity

| RPC | Definition hash production / staging | anon EXECUTE | authenticated EXECUTE prod / staging | service_role EXECUTE |
|---|---|---:|---:|---:|
| `krim_submit_partner_onboarding_global_multi_v1(...)` | Different | denied / denied | allowed / allowed | allowed / allowed |
| `krim_submit_partner_onboarding_global_v2(...)` | Different | denied / denied | allowed / denied | allowed / allowed |
| `krim_partner_submit_service_area(...)` | Identical | denied / denied | allowed / allowed | allowed / allowed |
| `krim_partner_register_capacity_resource(...)` | Identical | denied / denied | allowed / denied | allowed / allowed |

All four are SECURITY DEFINER with an empty search_path setting in both environments. The production and staging ACL drift on the two base/capacity functions is real and must be reconciled before relying on staging for live partner acceptance.

## Source-level authorization and evidence linkage

### Registered-business onboarding
- The frontend calls `krim_submit_partner_onboarding_global_multi_v1` after uploading the required registration document and optional insurance document.
- The wrapper requires `auth.uid()`, and staging's wrapper definition additionally requires JWT AAL2. Production's wrapper definition does not contain that explicit database-level AAL2 guard; the frontend itself checks MFA before upload.
- The wrapper validates the first path is under a numeric organization ID and the caller UID, then requires active membership in that same active partner organization in registered-business mode.
- It validates category coverage and delegates to `krim_submit_partner_onboarding_global_v2`.
- The base v2 function validates one or two document paths, requires the second path (if present) to use the same organization/user prefix and differ from the first, checks that every path exists in `krim-partner-verification`, and stores the exact paths in organization metadata and the verification case metadata.
- The base v2 function's staging EXECUTE grant is denied to authenticated, but the wrapper is SECURITY DEFINER and calls the base function internally. This is not itself proof of a browser-facing failure; the wrapper remains authenticated-executable in both environments.
- The wrapper definition hash differs between environments. The staging-only AAL2 guard is confirmed; the remaining full definition delta must be reconciled before release.

### Service-area evidence
- The RPC body is identical in production and staging.
- It checks the caller's partner.manage permission for the supplied organization, locks/validates an active registered-business partner organization and current compliance, validates the selected active country/market/location and service scope, and checks every evidence path has the exact organization/user/service-area prefix.
- It also verifies each object exists in the expected bucket and is owned by the submitting user, then persists the normalized paths in the service-area record metadata and writes an audit event.
- Authenticated EXECUTE is allowed in both environments.
- The frontend does not proactively guide users through AAL2 before upload. Staging's restrictive bucket INSERT policy will deny AAL1 uploads before this RPC is reached, producing a poor recovery experience.

### Capacity/resource evidence
- The RPC body is identical in production and staging.
- It checks auth.uid(), active organization membership, partner.manage, active partner organization type and current compliance; it also requires an active individually verified capability matching the requested transport mode and location country.
- Every submitted path must match the exact organization/user `capacity-{UUID}` filename pattern, exist in the expected bucket and be owned by the caller.
- Exact paths are persisted in capacity resource metadata. The created resource is `pending_review`; its associated availability is `unavailable` pending review.
- **Confirmed staging blocker:** authenticated EXECUTE is denied in staging while production allows it. The live browser page calls this RPC directly. After an AAL2 user successfully uploads capacity evidence in staging, the RPC will still fail at the function privilege boundary. Do not expose service_role credentials to the browser and do not grant broadly; use a narrowly reviewed, versioned ACL reconciliation after migration-history recovery.

## Required next actions
1. Reconcile the staging-only EXECUTE denial for the exact capacity overload through the canonical migration path. The historical migration ledger remains a release blocker; no live ACL change is made here.
2. Add guided MFA assurance/challenge handling to service-area and capacity upload pages so staging's AAL2 policy does not surface as an opaque Storage error.
3. Change service-area object naming to `crypto.randomUUID()`.
4. Compare the full onboarding wrapper/base v2 definitions, not just hashes, and document every intended environment-specific guard.
5. Run isolated Storage API tests for own-org allow, foreign-org and wrong-user denial, AAL1 denial, AAL2 success, authorized reads and linked-object cleanup.
6. Run dynamic positive/negative RPC tests with authorized synthetic fixtures in an isolated disposable test database. Live staging currently has no eligible verified partner/capability fixture; do not create fake verified partner data there.

## Release decision
No database or Storage policy changes are justified from this read-only review. Keep PR #245 draft. Capacity onboarding is not staging-ready because of the confirmed authenticated EXECUTE mismatch; service-area/capacity MFA UX and historical migration reconciliation also remain open.
