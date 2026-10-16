# KRIM Logistics OS — Master File & Architecture Checklist

**Purpose:** Canonical index for the build contracts and architecture documents. These documents are linked to each other as the system's design/governance reference; they do not themselves connect or activate runtime code.

## Status Legend
- [x] File exists in the repository and has been linked/reconciled in this index.
- [ ] File does not yet exist or has not been reconciled.
- **Runtime verification is tracked separately.** A checked document is not proof that its design is implemented, deployed, secure, or production-ready.

## 1. Master and Build Contracts
- [x] [Master file checklist](KRIM-MASTER-FILE-CHECKLIST.md)
- [x] [Global build contract](KRIM-GLOBAL-BUILD-CONTRACT.md)
- [x] [Frontend architecture specification](KRIM-FRONTEND-ARCHITECTURE.md)
- [x] [Institutional interface standard](KRIM-INSTITUTIONAL-INTERFACE-STANDARD.md)
- [x] [Frontend Batch 1 lock](KRIM-FRONTEND-BATCH-1-LOCK.md)
- [x] [Frontend integration contract](FRONTEND-INTEGRATION-CONTRACT.md)
- [x] [Frontend architecture overview](frontend-architecture.md)

## 2. Architecture Reference
- [x] [System context](architecture/system-context.md)
- [x] [Global system architecture](architecture/global-system-architecture.md)
- [x] [Application boundaries](architecture/application-boundaries.md)
- [x] [Tenant isolation model](architecture/tenant-isolation-model.md)
- [x] [User lifecycle map](architecture/user-lifecycle-map.md)
- [x] [Shipment lifecycle map](architecture/shipment-lifecycle-map.md)
- [x] [Payment lifecycle map](architecture/payment-lifecycle-map.md)
- [x] [Partner lifecycle map](architecture/partner-lifecycle-map.md)
- [x] [Data flow map](architecture/data-flow-map.md)
- [x] [Trust boundaries](architecture/trust-boundaries.md)
- [x] [Threat model](architecture/threat-model.md)
- [x] [Global market activation](architecture/global-market-activation.md)
- [x] [System dependency map](architecture/system-dependency-map.md)
- [x] [Architecture decision records](architecture/architecture-decision-records.md)
- [x] [Non-functional requirements](architecture/nonfunctional-requirements.md)
- [x] [Deprecation and migration policy](architecture/deprecation-and-migration-policy.md)
- [x] [Definition of done](architecture/definition-of-done.md)
- [x] [Production readiness criteria](architecture/production-readiness-criteria.md)

## 3. How the Documents Connect
1. **Build contract** sets global-first product and engineering principles.
2. **Frontend architecture + integration contract** govern browser structure and frontend-to-backend API behavior.
3. **System context + global architecture + application boundaries** define the system shape and trust separation.
4. **Tenant isolation + trust boundaries + threat model** define security requirements and negative tests.
5. **User, shipment, payment and partner lifecycle maps** define business state machines and actors.
6. **Data flow + dependency map + ADRs** describe sensitive data movement, dependencies and major choices.
7. **Global market activation + non-functional requirements** govern country activation, localization, resilience and performance.
8. **Migration policy** governs safe evolution of schemas, APIs and pages.
9. **Definition of done + production readiness criteria** provide release gates and evidence requirements.

## 4. Runtime Integration and Verification (Tracked Separately)
- [ ] Confirm current repository routes/pages and eliminate broken links.
- [ ] Verify shared frontend configuration and Supabase client use.
- [ ] Verify each UI action against the actual Edge Function/RPC/table contract.
- [ ] Run tenant-isolation and role/permission negative tests using non-service-role identities.
- [ ] Verify payment success only after authoritative provider/server confirmation.
- [ ] Test public contact and tracking flows end-to-end with valid and invalid inputs.
- [ ] Verify deployment and browser behavior on mobile and desktop.
- [ ] Review Supabase security findings, function grants, RLS policies, secrets and operational logs.
- [ ] Attach test evidence before marking production readiness complete.

## 5. Change Control
When a system boundary or workflow changes, update the relevant lifecycle/architecture document and this index in the same change. Never mark runtime verification complete merely because documentation or code exists. See [deprecation and migration policy](architecture/deprecation-and-migration-policy.md) and [definition of done](architecture/definition-of-done.md).
