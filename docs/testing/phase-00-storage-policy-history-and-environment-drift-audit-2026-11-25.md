# Phase 00 — Storage policy history and live environment drift audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Projects inspected read-only:
- Production: `ebltviniygljwwseplph`
- Staging: `qrpcivhdxobiaofppbkl`

## Verdict
**FAIL — Staging Storage policy composition is unsafe, and Production/Staging Storage configuration is materially divergent.** No policy, bucket, migration, object, secret, or application changes were made.

## 1. Live migration-history reconciliation
| Environment | Applied migration rows | Latest version | Latest migration name |
|---|---:|---|---|
| Production | 561 | `20261124071550` | `krim_report_operational_exception` |
| Staging | 34 | `20261123044931` | `refine_admin_driver_licence_expiry_rpc_security` |

The environments do not have matching applied migration histories. The Production history contains hundreds of additional migrations beyond Staging's latest recorded version. This is not a small tail difference and cannot be treated as safe parity.

Important qualification: this comparison establishes migration-history divergence; it does not prove that every missing Production migration is required for every Staging workflow. However, Storage policy and bucket differences below confirm practical Storage drift.

## 2. Live bucket configuration
All buckets are private in both environments where present.

### Production — 5 buckets
| Bucket | Max size | Allowed MIME |
|---|---:|---|
| `krim-driver-evidence` | 10 MiB | JPEG, PNG, WebP, PDF |
| `krim-driver-verification` | 10 MiB | JPEG, PNG, WebP, PDF |
| `krim-partner-verification` | 10 MiB | PDF, JPEG, PNG |
| `krim-warehouse-evidence` | 10 MiB | JPEG, PNG, PDF |
| `pod-documents` | Not configured | Not configured |

### Staging — 1 bucket
| Bucket | Max size | Allowed MIME |
|---|---:|---|
| `krim-partner-verification` | 10 MiB | PDF, JPEG, PNG |

Staging is missing the Production driver evidence, driver verification and warehouse evidence buckets. The legacy POD bucket exists only in Production and has no bucket-level size/MIME constraints. It is private, and the legacy policies were retired in Production. Do not assume this legacy bucket is a supported current workflow.

## 3. Live Storage object-policy inventory
### Production — 26 policies
- `krim-driver-evidence`: 4 policies — driver own-assignment SELECT/INSERT, verified-POD customer SELECT, platform-admin AAL2 SELECT.
- `krim-driver-verification`: 3 policies — own upload, admin read, unregistered upload cleanup.
- `krim-partner-verification`: 16 policies — partner own-org upload/read, admin read, customs shipment and broker-license upload/read/cleanup, claim evidence upload/read/admin/cleanup, capacity and service-area orphan cleanup.
- `krim-warehouse-evidence`: 3 policies — upload, read, unregistered cleanup.
- `pod-documents`: no active object policies in the current live inventory.

### Staging — 3 policies
All three policies target `krim-partner-verification`:
1. `krim_partner_verification_read_own_org` — SELECT, scoped by active membership and organization path.
2. `krim_partner_verification_upload_own_org` — INSERT, scoped by authenticated user path and active partner organization membership.
3. `krim_partner_verification_upload_require_aal2` — INSERT, checks only bucket ID and AAL2.

Staging has no live object policies for the Production driver-evidence, driver-verification or warehouse-evidence buckets because those buckets are absent there.

## 4. Critical Staging policy-composition defect — confirmed
The Staging policy `krim_partner_verification_upload_require_aal2` is permissive and checks only:
- bucket = `krim-partner-verification`
- JWT AAL = `aal2`

It does **not** check:
- organization membership or active organization status;
- organization folder path;
- uploader/user folder path;
- owner identity;
- evidence workflow or registration state.

PostgreSQL combines permissive policies for the same command using OR semantics. Therefore an authenticated AAL2 user can satisfy this broad INSERT policy even when the stricter `krim_partner_verification_upload_own_org` policy would reject the object path. This defeats the intended tenant/uploader path restriction for uploads in Staging.

This is a confirmed policy-level access widening from the live policy expressions. It was not demonstrated with a real upload, and no such test was attempted. Production does **not** have this extra AAL2-only INSERT policy in its current live inventory.

**Do not use Staging for partner verification evidence uploads or sensitive upload testing until the policy composition is corrected and independently verified.**

## 5. Migration-source reconciliation
Reviewed relevant QA-branch migrations:
- `20261105151615_align_partner_evidence_storage_org_types.sql` — recreates partner own-organization SELECT and INSERT policies with active membership and path constraints.
- `20261107152000_customs_document_storage_and_broker_read_policies.sql` — creates shipment customs document upload/read policies scoped to customer or accepted broker access.
- `20261107184000_scope_customs_broker_license_storage.sql` — scopes broker-license upload and unregistered-object cleanup to the user's active customs organization and compliance permission.
- `20261105071000_retire_legacy_pod_documents_bucket_policies.sql` — removes three legacy `pod-documents` object policies.
- `20261111130000_restrict_customer_pod_reads_to_verified_evidence.sql` — limits customer POD record visibility to verified POD state and customer organization access.
- `20261115123000_restrict_partner_verification_case_mutations_to_aal2_rpc.sql` — restricts verification-case database mutations to audited AAL2 RPCs; it does not authorize a broad Storage INSERT policy.

The live Staging AAL2-only Storage policy was not found in the inspected repository migration files. The 34-row Staging migration history also does not contain the relevant later Storage policy migrations listed above. This indicates the extra policy is not represented by the inspected migration source/history and needs provenance investigation; do not assume it is a deliberate or safe migration.

## 6. Required remediation sequence — not executed
1. Preserve current evidence and identify the exact origin of `krim_partner_verification_upload_require_aal2` (dashboard/manual SQL, branch migration, or external automation).
2. Prepare a reviewed Staging-only migration that removes the broad AAL2-only INSERT policy, preserving only the correctly scoped own-organization policy. Do not run it until the SQL is reviewed and explicit approval is obtained.
3. Reconcile the full intended migration set before using Staging as a runtime test environment. Do not blindly replay all Production migrations or reset either database.
4. Bring Staging Storage buckets, constraints, and policy definitions to a deliberately selected, documented test baseline. Staging must not be copied blindly from Production; it needs test isolation and synthetic tenant fixtures.
5. Add automated catalog assertions that compare bucket names, public flags, size/MIME constraints, policy names, command, roles, USING and WITH CHECK expressions between intended environments.
6. Run isolated negative/positive tests for own-org upload, wrong-org path, another user's path, AAL1, AAL2, admin read, customs shipment, claims, driver assignment, verified-POD customer read and warehouse evidence. Use synthetic users and test objects only after safe test isolation is established.
7. Verify that a policy change did not accidentally widen SELECT, UPDATE or DELETE access and that cleanup policies cannot delete registered evidence.

## 7. Safety and evidence boundaries
- Queries were read-only catalog and migration-history SELECTs.
- No Storage object names or contents were listed/read.
- No uploads, downloads, signed URLs or live JWT tests were performed.
- No Production or Staging changes were made.
- No migration was applied, rolled back, reset, or replayed.
- Live database state was compared with selected QA-branch migration sources; this is not a complete line-by-line reconstruction of all 561 Production migrations.
- A policy-level vulnerability finding is not the same as proof of a successful exploit against a real account.

## Final status
**Storage environment parity: FAIL.**
**Staging partner evidence upload isolation: FAIL — critical permissive-policy OR bypass.**
**Production Storage policy catalog: inventory captured; runtime tenant-isolation tests remain NOT VERIFIED.**
**Production/Stage mutation: none.**
