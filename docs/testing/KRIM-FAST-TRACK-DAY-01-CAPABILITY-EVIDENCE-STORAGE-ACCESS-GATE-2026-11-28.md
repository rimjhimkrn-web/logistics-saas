# KRIM Fast-Track Day 1 — Capability Evidence Storage and Access Gate
Date: 2026-11-28
Environment: Staging project qrpcivhdxobiaofppbkl; read-only catalog and aggregate inspection
Branch: staging/phase00-env-isolation

## Result
DESIGN GATE COMPLETE FOR THE CURRENT CAPABILITY TABLE. A safe evidence-history implementation must introduce its own durable submission identity/history. Do not assume capability metadata or current indexes provide that history.

## Staging evidence

### Current capability table
The Staging public.krim_partner_capabilities table has these relevant columns:
- id bigint primary key
- organization_id bigint not null
- transport_mode_id bigint not null
- service_type text not null
- coverage_country_id bigint nullable
- coverage_region text nullable
- active boolean not null
- verification_status text nullable
- metadata jsonb nullable

No submitted_by, submitted_at or evidence_paths columns exist as first-class columns; the existing evidence submission flow stores these values in metadata.

### Constraints
Current checks constrain:
- effective_until >= effective_from where effective_until is set;
- verification_status to pending, verified, rejected, expired or suspended;
- service_type to transport, warehouse, freight_forwarding, last_mile, first_mile, customs or other.

Foreign keys link organization, transport mode and country. Primary key is id.

### Indexes
Current indexes cover country, transport mode, organization and (organization_id, verification_status, active), plus the primary key. No unique index/constraint enforces a unique capability declaration for an organization + mode + service + country + region. A new implementation must define its own concurrency/idempotency boundary and must not assume a natural unique key exists.

### RLS and grants
- RLS is enabled on public.krim_partner_capabilities.
- An organization-access SELECT policy exists.
- The authenticated database role has no direct SELECT, INSERT or UPDATE table privilege in the inspected privilege snapshot.
- service_role has SELECT.
- Therefore the partner UI's direct table read is not proven to work with the current grants. It may rely on a different access path, view, RPC or client privilege state; this must be traced and tested before changing grants.
- Do not grant broad authenticated table access to make the page work. Prefer narrowly scoped RPCs or a dedicated safe read surface.

### Current Staging data
Aggregate-only inspection returned zero rows in public.krim_partner_capabilities at the time of the query. Therefore no real partner capability/declaration records were inspected or modified, and no row-level migration/backfill can be validated against live examples yet.

## Required data model decision

Recommended new table (name illustrative, not created):
public.krim_partner_capability_submissions

Minimum columns:
- id bigint identity primary key
- capability_id bigint not null references public.krim_partner_capabilities(id)
- organization_id bigint not null references public.krim_organizations(id)
- submitted_by uuid not null
- submitted_at timestamptz not null default now()
- submission_version integer not null
- evidence_paths text[] not null
- submission_details jsonb not null default '{}'
- request_key uuid not null
- status text not null (submitted, superseded, accepted, rejected, withdrawn)
- created_at timestamptz not null default now()

Required constraints/indexes:
- unique (capability_id, submission_version)
- unique (organization_id, submitted_by, request_key) for idempotent retries
- check array cardinality 1..5 and non-empty/distinct paths
- check JSON object and size/field limits
- indexes on capability_id + submitted_at and organization_id + submitted_at
- no direct anon/authenticated table grants; access only through narrowly scoped authenticated RPCs
- RLS enabled as defense in depth; private schema is an alternative if no direct Data API surface is needed

Do not add a cascading delete that destroys evidence history when a capability is removed. Prefer RESTRICT/soft-retire and explicit retention policy.

## RPC contract implications
1. Attach-evidence RPC must lock the target capability and enforce partner.manage on the exact organization.
2. Derive submitter from auth.uid(); reject caller-supplied actor identity.
3. Validate active registered-business partner status and required compliance state.
4. Validate 1–5 unique Storage object paths, exact organization/user/capability folder, bucket name and actual owner.
5. Validate every input before writing; insert one append-only submission version.
6. Use request_key for idempotency; identical retry returns the original submission result.
7. Do not promote the capability. Keep active=false and verification_status='pending' until independent admin review.
8. Admin review must reference a specific submission version and persist reviewer, decision, reason and timestamps.
9. A new evidence submission after rejection must be a new version, not an overwrite of prior evidence/review history.
10. Ensure the existing admin review RPC can consume the selected submission version, or introduce a versioned review RPC and deprecate the old path safely.

## Frontend dependency gate
The current services-capabilities page performs a direct select from krim_partner_capabilities and submits new evidence through krim_partner_submit_service_capability_v2. Before changing it:
- establish the real read path and whether its select currently succeeds under authenticated grants;
- add a safe pending-declaration list/read RPC if required;
- allow selection of a specific declaration id;
- call the attach-evidence RPC for that declaration;
- retain the existing insert flow only for genuinely new capabilities;
- reconcile upload cleanup for partial failures and uncertain RPC outcomes;
- never silently retry a request whose database outcome is unknown.

## Tests required before deployment
- no JWT / anonymous / wrong AAL;
- wrong tenant, inactive membership, missing partner.manage;
- individual/development-test org rejected;
- missing, duplicate, foreign-owner, wrong-bucket, wrong-folder and nonexistent object paths;
- 0, 1, 5 and 6 evidence files;
- invalid JSON and oversize fields;
- repeated request_key and same payload idempotency;
- same request_key with different payload rejected;
- concurrent submissions serialize and do not fork version numbers;
- rejected submission followed by a new version;
- verified/suspended/expired capability cannot be silently reset;
- reviewer cannot approve own submission;
- review references exact submission version;
- rollback leaves no partial submission or orphaned DB references;
- direct table access denied to anon/authenticated and least-privilege RPC EXECUTE verified.

## Limitations and safety
- This is a read-only Staging audit and data-model recommendation, not an applied schema.
- No migration was generated or applied.
- No grants, policies, table, RPC, fixture, upload or test record were created.
- No notification, email, payment or external provider was invoked.
- Production was not accessed.
- Full repository-wide dynamic/indirect caller certification remains open; the earlier 115-file targeted partner scan is not equivalent to a complete 1,210-file scan.

## Disposition
STAGING DATA-MODEL GATE DOCUMENTED. Implementation remains blocked on the safe read path, submission version/review linkage, complete caller certification and an executable isolated test plan. Phase 00 remains OPEN.
