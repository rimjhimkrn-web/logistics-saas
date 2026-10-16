# KRIM Frontend Architecture Overview

**Purpose:** Canonical overview of the browser application structure and how it integrates with the global KRIM backend.

## 1. Architectural Shape
KRIM is a multi-surface logistics platform, not a single dashboard. Public discovery, identity, customer and partner operations, enterprise workflows, finance, and privileged platform administration have separate access boundaries while sharing a consistent design system and API contract.

Expected logical layers:
1. **Public experience** — marketing, coverage, solutions, guides, status and privacy-safe tracking.
2. **Identity** — registration, sign-in, verification, recovery, MFA and session handling.
3. **Role workspaces** — customer, partner/carrier, driver, warehouse, customs, enterprise and finance experiences.
4. **Platform control** — restricted global administration, audit, security, integrations and operational health.
5. **Shared frontend core** — tokens, components, navigation, configuration, Supabase client and common request/error utilities.
6. **Backend boundary** — Supabase Auth, RLS-protected data access, narrowly scoped RPCs and Edge Functions.

These are logical boundaries. Actual file names and capabilities must be confirmed from the current repository before being treated as implemented.

## 2. Dependency Direction
- Page-specific UI may depend on shared core modules.
- Shared core modules must not depend on a specific workspace page.
- Public pages must not import privileged control-centre modules.
- Browser code must not contain service-role or payment-provider secret keys.
- All privileged operations cross a server-side authorization boundary.
- Avoid duplicate configuration, multiple conflicting Supabase clients, and hard-coded environment-specific URLs.

## 3. Navigation and Routing
- Links must work under the actual hosting base path; GitHub project Pages commonly serve the project beneath a repository path.
- Keep public navigation separate from authenticated workspace navigation and platform-control navigation.
- Do not expose privileged admin entry points in public navigation.
- Every navigation destination must exist, have an intentional access policy, and provide a useful not-found/unauthorized state.
- Verify mobile navigation and keyboard/accessibility behavior on deployed pages.

## 4. Security Requirements
- Browser input is untrusted.
- UI visibility is not authorization.
- Enforce identity, tenant membership, role permissions, resource ownership, and lifecycle transitions on the server.
- Use safe DOM rendering for remote data.
- Do not store secrets in local storage or source files. Use the provider's supported session mechanism and apply a documented token/session policy.
- Public tracking and contact workflows must expose only narrowly scoped information and have abuse protection.

## 5. Runtime Integration Checklist
- [ ] One canonical configuration source for Supabase URL and publishable key.
- [ ] All active pages use supported shared modules or clearly documented exceptions.
- [ ] Every form/action has a real backend contract; no fake success state.
- [ ] Tenant isolation and RBAC are tested beyond the UI.
- [ ] Loading, empty, error, timeout and retry states exist.
- [ ] Payment state is based on verified server/provider events.
- [ ] Mobile and desktop browser tests pass.
- [ ] Deployment base paths, redirects, and 404 handling are verified.

## 6. Architecture References
- [Frontend integration contract](FRONTEND-INTEGRATION-CONTRACT.md)
- [Global build contract](KRIM-GLOBAL-BUILD-CONTRACT.md)
- [Frontend architecture specification](KRIM-FRONTEND-ARCHITECTURE.md)
- [Institutional interface standard](KRIM-INSTITUTIONAL-INTERFACE-STANDARD.md)
- [System context](architecture/system-context.md)
- [Global system architecture](architecture/global-system-architecture.md)
- [Application boundaries](architecture/application-boundaries.md)
- [Tenant isolation model](architecture/tenant-isolation-model.md)
- [Threat model](architecture/threat-model.md)
- [Production readiness criteria](architecture/production-readiness-criteria.md)

**Status caution:** This document describes the intended architecture and verification gates. It is not evidence that every listed page or workflow currently meets them.
