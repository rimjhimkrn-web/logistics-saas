# KRIM Fast-Track Day 01 — Full Migration Collision Classification
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Inspected head: `b27c2af0d2adaf96e1dba24a9709b4f4122ef6d8`
Staging project: `qrpcivhdxobiaofppbkl`
Production: not accessed or changed

## Scope and method
Re-read the complete Git tree and fetched the contents of all 61 SQL files belonging to the 29 duplicate 14-digit migration-version groups. This is a source-level classification, not proof that any file was or was not applied to Staging. No SQL was executed.

## Classification summary
- 29 duplicate-version groups reviewed.
- 61 files reviewed.
- 1 explicitly superseded no-op file.
- 60 files contain substantive SQL changes (DDL, DML, function/policy/trigger replacement, grants or constraints).
- At least one group contains four separate substantive files; one group contains three separate substantive files.
- No group should be treated as a safe single migration without a deterministic ordering and dependency review.

## Group-by-group classification

| Version | Files | Source-level classification | Replay concern |
|---|---:|---|---|
| `20261025150000` | 2 | One substantive initial-shipment-leg trigger migration; one explicit no-op saying localization seed was superseded by version `20261025143459`. | Keep no-op distinct from substantive file; verify historical migration source before any ledger action. |
| `20261104190000` | 4 | Driver profile transfer guard; driver/carrier invitation and membership schema/RPC; driver verification documents and admin review; partner route scope and driver verification. | Four independent changes with dependencies across driver profiles, invitations, partner capabilities and shipment assignments. |
| `20261104191500` | 2 | Driver review guard replacement; confirmed-email gate for invitation acceptance. | Both replace/add driver authorization behavior; order relative to base invitation functions matters. |
| `20261104192500` | 2 | Driver invitation acceptance function correction; restrictive pending-profile document-upload policy. | Function and RLS policy changes must be ordered against prior driver invitation/document schema. |
| `20261104193000` | 2 | Driver profile verification guard replacement; secure driver membership invitation RPCs. | Both alter invitation/profile security; function definitions depend on earlier invitation objects. |
| `20261104223000` | 2 | AAL2 admin country-pack read RPCs; market activation enforcement in shipment creation. | Independent country governance and shipment booking gate changes. |
| `20261104230000` | 2 | Corridor compliance dossier schema/admin workflow; market activation helper and unified shipment-creation gate. | Compliance and market activation dependencies require explicit ordering. |
| `20261104234500` | 2 | Draft Ranchi–Jamshedpur pilot candidate seed; proposed corridor catalogue seed. | Both insert candidate catalogue data; inspect for duplicate/conflicting corridor codes and source catalogue prerequisites. |
| `20261105153000` | 2 | Evidence-backed partner capability submission RPC; partner quote-create permission grant and function hardening. | Separate partner onboarding/evidence and quote authorization changes. |
| `20261106160000` | 2 | Customs broker assignment table foundation; linked warehouse goods-receipt workflow RPC. | Both depend on pre-existing shipment/customs/warehouse schemas; not a clean baseline. |
| `20261106180000` | 2 | Driver assignment acceptance/trip event RPCs; operations dispatch readiness register. | Separate driver lifecycle and operations read model. |
| `20261106190000` | 2 | Driver assignment shipment-leg identity and assignment RPC changes; global vehicle registry schema/RPCs. | Vehicle registry and exact-leg assignment changes have cross-dependencies. |
| `20261115151000` | 2 | Tightened driver evidence acceptance/review; scheduled private vehicle evidence expiry worker. | One changes driver document rules; the other creates scheduler/cron side effects. Never replay without scheduler and environment review. |
| `20261126230000` | 2 | Disables legacy freight/payment reconciliation paths; guards invoice lifecycle and prevents unapproved invoice mutations. | Both are critical finance safety controls; validate current KRIM direct-pay model before any replay. |
| `20261127027000` | 2 | Enforces driver-to-partner assignment and exact-leg foreign-key identity; rewrites capacity-hold expiry/reconciliation function with source-definition hash guard. | One is structural constraints; the other is guarded function replacement. |
| `20261127028000` | 2 | Exact POD-to-partner-assignment identity constraint; prevents partner-assignment delete/truncate and protects history. | Structural integrity and immutable history protections. |
| `20261127029000` | 2 | Exact dispatch/capacity/assignment composite identity constraints; monotonic partner-assignment state transition trigger. | Both affect live logistics invariants; constraint and transition logic need dependency ordering. |
| `20261127077000` | 2 | Expands notification type constraint for partner/driver events; makes unsupported workflow actions fail closed. | Separate notification schema and workflow executor changes. |
| `20261127084000` | 2 | Bounded workflow dispatch retries/runtime batch; freezes workflow configuration while work is queued/running. | Both affect runtime behavior and scheduler execution; require isolated workflow test lane before execution. |
| `20261127090000` | 2 | Emits driver assignment status events/in-app notifications; makes partner verification storage AAL2 policy restrictive. | Notification event migration has real side effects; storage policy is independent. |
| `20261127123000` | 2 | Blocks assignment to drivers with expired licences; enforces one active shipment leg plan per shipment. | Separate driver eligibility and route-plan uniqueness safeguards. |
| `20261127150000` | 2 | Grants scoped authenticated quote SELECT columns; requires identity evidence before driver assignment. | Independent grants/RLS and driver assignment hardening. |
| `20261127160000` | 2 | Adds immutable customer quote acceptance evidence and acceptance RPC; serializes driver assignment against vehicle unbind and tightens expiry-day licence eligibility. | Two separate operational safety changes; second rewrites existing assignment function by exact text anchors. |
| `20261127162000` | 2 | Restricts POD completion to exact driver assignment identity; revalidates dispatch authorization before exception recovery. | Both replace existing operational function bodies; source definitions must match expected anchors. |
| `20261127164000` | 2 | Keeps dispatch currentness valid through trip states; requires fresh POD evidence after rejection. | Separate function rewrites; must be ordered against POD/dispatch versions. |
| `20261127168000` | 2 | Adds fresh-evidence predicate to admin POD review; pins shipment terminal guard search_path. | Two distinct operations. The POD review change is very similar to a second file at version `20261127169000`; compare source anchors and history before deciding whether one supersedes the other. |
| `20261127169000` | 2 | Adds another fresh-evidence predicate to admin POD review using a slightly different exact text anchor; requires the exact shipment leg to be in transit for POD submit/authorization. | Potential overlapping/superseding POD-review patch with `20261127168000`; do not blindly apply both. |
| `20261127170000` | 2 | Adds immutable partner quote response evidence trigger; requires exact multi-leg plan completion. | Separate quote evidence and shipment completion invariants. |
| `20261127190000` | 3 | Grants authenticated own-user preference access; adds capacity event lineage foreign keys/indexes; creates organisation-scoped partner response evidence read RPC. | Three independent operations with different security and schema dependencies; split into separate ordered migrations. |

## Highest-risk ordering collisions

### A. Driver invitation and verification sequence
Versions `20261104190000`, `20261104191500`, `20261104192500`, and `20261104193000` contain multiple replacements of driver guard/invitation functions and document policies. Their correct sequence must be recovered from commit chronology and the actual function definitions expected at each step. A simple alphabetical filename order is not an adequate dependency proof.

### B. Driver assignment / vehicle / POD / dispatch sequence
Versions `20261106190000`, `20261115151000`, `20261127027000`, `20261127028000`, `20261127029000`, `20261127123000`, `20261127150000`, `20261127160000`, `20261127162000`, `20261127164000`, `20261127168000`, and `20261127169000` contain related identity constraints, driver eligibility, dispatch currentness, POD evidence and function replacements. Replaying them in arbitrary order risks missing expected function anchors or applying an intermediate function body after a later hardening change.

### C. Workflow and notification sequence
Versions `20261127077000`, `20261127084000`, and `20261127090000` affect workflow action execution, retry behavior, workflow configuration immutability and real notification event creation. They must not be replayed in an environment where test events can reach live notifications/email workers.

### D. Finance guard sequence
Version `20261126230000` contains two critical finance controls. The intended end state must preserve disabled freight collection, partner payouts and legacy reconciliation until the KRIM fee model and legal/accounting controls are approved.

## Recommended recovery decision
Do not merely retimestamp 60 files. First reconstruct their intended order from Git commit ancestry, dependency references and the Staging schema/function state. Then produce a new, reviewed migration chain with unique version identifiers in a dedicated recovery branch. The local disposable database must start from an owner-approved schema-only Staging baseline, not from an assumed empty database.

The migration ledger mismatch remains a separate issue: the Staging ledger has 163 entries, and only three versions exactly match repository filename prefixes. File classification does not resolve this history divergence.

## Gate status
- Duplicate-version groups classified at source level: **29/29**.
- Files in those groups inspected: **61/61**.
- Safe deterministic replay chain: **NOT ESTABLISHED**.
- Staging migration mutation: **NOT AUTHORIZED / NOT PERFORMED**.
- Partner A/B authenticated tests: **NOT RUN**.
- Phase 00: **OPEN — NOT APPROVED**.
- Production: **NOT ACCESSED OR CHANGED**.
