# KRIM Storage bucket and object-policy parity — first-pass audit — 2026-11-24

Projects compared read-only:
- Production: `ebltviniygljwwseplph`
- Staging: `qrpcivhdxobiaofppbkl`

No Storage bucket, object, or policy was changed.

## Bucket inventory

| Bucket | Production | Staging | Observation |
|---|---|---|---|
| `krim-driver-evidence` | Private, 10 MiB, JPEG/PNG/WebP/PDF | Missing | Driver evidence upload and verified-POD evidence retrieval cannot be assumed to work in staging. |
| `krim-driver-verification` | Private, 10 MiB, JPEG/PNG/WebP/PDF | Missing | Driver verification upload/review path lacks its bucket in staging. |
| `krim-partner-verification` | Private, 10 MiB, PDF/JPEG/PNG | Private, same limits | Only common bucket. |
| `krim-warehouse-evidence` | Private, 10 MiB, JPEG/PNG/PDF | Missing | Warehouse evidence path lacks its bucket in staging. |
| `pod-documents` | Private, no bucket-level size/MIME restriction | Missing | Production ePOD document bucket is absent from staging; signed-link access model needs separate review. |

## Object policy inventory

- Production: 24 policies on `storage.objects`.
- Staging: 3 policies.
- Two policies are common by name and purpose: partner verification read-own-organization and upload-own-organization.
- Staging adds a restrictive AAL2 requirement to partner-verification INSERT. Production does not have that extra policy.
- The remaining production policies cover driver evidence, driver verification, customs broker licenses and shipment customs documents, claim evidence, warehouse evidence, verified POD customer access, and scoped platform-admin preview/review/cleanup.

Policy names are not sufficient to establish semantic parity. The production and staging versions of the two common partner policies are logically similar but differ in SQL qualification style (`auth.uid()` vs scalar subselect). Their predicates should be normalized and tested before classifying as identical.

## Positive security observations in production definitions

- All five production buckets are private.
- Driver evidence upload/read policies bind object paths to `auth.uid()`, the driver's own assignment and active driver membership.
- Customer access to driver evidence is limited to evidence paths referenced by a verified POD record and the shipment's customer organization membership.
- Customs document reads are tied to submitted document records and customer shipment permission, accepted broker assignment, or AAL2 platform-admin permission.
- Claim evidence reads are scoped to claimant/respondent organization access; uploads are tied to the user's active organization membership and claim status.
- Warehouse evidence paths require an eligible warehouse organization, active membership and `partner.manage`.
- Partner verification uploads/read paths bind the organization folder to active membership and active organization status.
- Platform-admin access to sensitive driver/customs/warehouse evidence includes AAL2 checks in the reviewed policies.

These are source-level policy observations, not completed cross-tenant Storage API tests.

## Gaps and risks

1. **Staging bucket incompleteness:** four of five production buckets are absent. Staging cannot serve as a complete Storage acceptance environment for driver, warehouse, or ePOD flows.
2. **Policy incompleteness:** 22 production policy names are absent from staging (24 production vs 3 staging, with two common policy families). Do not bulk-copy them without dependency, path, bucket and workflow review.
3. **AAL2 asymmetry:** staging's restrictive AAL2 upload policy is stricter than production for partner verification. This may be intentional hardening, but it can block legitimate onboarding uploads for AAL1 sessions. Test MFA completion and upload behavior before parity changes.
4. **Private ePOD bucket:** `pod-documents` has no corresponding bucket in staging. Production has no direct `storage.objects` policy in the listed policy set for this bucket, which is consistent with a service-mediated/signed-link design but requires checking edge-function and signed-URL issuance paths before any change.
5. **Policy migration history remains unreconciled:** no new bucket or policy should be created in staging until the historical migration source and intended rollout order are recovered.

## Next review slice
Review `krim-partner-verification` in detail first: upload path builders, object naming conventions, registered-business onboarding and service-area/capacity evidence workflows, AAL2 requirements, cleanup rules, and frontend Storage API call sites. Then test own-organization allow and foreign-organization deny in an isolated staging test harness. No broad bucket/policy replication is recommended.
