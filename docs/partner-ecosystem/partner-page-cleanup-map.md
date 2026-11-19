# KRIM Partner Page Cleanup Map

**Repository:** `rimjhimkrn-web/logistics-saas`  
**Branch audited:** `staging/owner-admin-url-fix`  
**Source inventory:** `assets/krim-owner-testing-manifest.json`  
**Inventory scope:** 122 partner-related entries from an 870-page manifest.  
**Status:** Planning document only. No application pages have been deleted, renamed, redirected, or modified by this commit.

## Purpose and safety rules
- Establish one coherent Partner journey and remove placeholder pages from active navigation.
- A recommendation to archive means hide from navigation first; it does **not** authorize physical deletion.
- Preserve old URLs until inbound links, bookmarks, redirects, analytics and route dependencies are checked.
- Do not expose admin/finance pages to partner roles. Verify MFA, organization membership, row-level access and storage permissions before launch.
- Do not activate freight collection, escrow, settlement or payout features without approved legal/commercial design.
- Staging visual/interactive demos are not proof of live Supabase functionality.

## Status definitions
- **KEEP:** retain as an active page or module, subject to functional and access testing.
- **REDIRECT / ALIAS:** preserve URL compatibility but remove duplicate entry from navigation.
- **REVIEW:** retain temporarily; compare function, permissions, dependencies or legal meaning before deciding.
- **ARCHIVE FROM NAV:** placeholder/prototype should not appear as a live capability; do not delete until dependency checks pass.

## Page-by-page inventory and recommendation

| Page path | Decision | Reason / next action |
|---|---|---|
| `app/finance/partner-settlements.html` | **KEEP** | Internal finance interface; restrict by finance permissions. |
| `app/partner/business/index.html` | **KEEP** | Registered business partner workspace. |
| `app/partner/carrier/active-shipments.html` | **KEEP** | Carrier active shipments. |
| `app/partner/carrier/exception-reporting.html` | **KEEP** | Carrier exception reporting. |
| `app/partner/carrier/index.html` | **KEEP** | Carrier operations workspace. |
| `app/partner/carrier/milestone-updates.html` | **KEEP** | Carrier milestone updates. |
| `app/partner/carrier/performance-quality.html` | **REVIEW** | Carrier-specific scorecard; compare metrics, source tables and permissions against public scorecard. |
| `app/partner/customs/index.html` | **KEEP** | Customs partner workspace. |
| `app/partner/development/index.html` | **REVIEW** | Development/test workspace; isolate from production navigation. |
| `app/partner/driver-vehicle-assignment.html` | **KEEP** | Driver/vehicle compatibility and assignment. |
| `app/partner/first-mile/index.html` | **KEEP** | First-mile workspace. |
| `app/partner/forwarder/index.html` | **KEEP** | Freight forwarder workspace. |
| `app/partner/index.html` | **KEEP** | Partner workspace gateway. |
| `app/partner/individual/index.html` | **KEEP** | Independent partner workspace. |
| `app/partner/integrations-automation.html` | **REDIRECT / ALIAS** | Existing alias to public/partner/integrations-automation.html. |
| `app/partner/last-mile/index.html` | **KEEP** | Last-mile workspace. |
| `app/partner/multimodal/index.html` | **KEEP** | Multimodal workspace. |
| `app/partner/security-audit.html` | **REDIRECT / ALIAS** | Existing alias to public/partner/security-audit.html. |
| `app/partner/specialist/index.html` | **KEEP** | Specialist services workspace. |
| `app/partner/vehicle-registry.html` | **KEEP** | Vehicle registry and documents. |
| `app/platform-admin/partner-capabilities.html` | **KEEP** | Admin capability review. |
| `app/platform-admin/partner-compliance.html` | **KEEP** | Admin compliance review. |
| `app/platform-admin/partner-service-areas.html` | **KEEP** | Admin service-area review. |
| `app/platform-admin/partner-verification.html` | **REVIEW** | Primary admin verification candidate; still verify runtime MFA and role enforcement. |
| `auth/partner-redirect.html` | **KEEP** | Post-auth partner routing; verify role and organization guards. |
| `auth/partner-signin.html` | **KEEP** | Existing partner sign-in. |
| `auth/partner-signup.html` | **KEEP** | Account registration. |
| `control/partner-verification.html` | **REVIEW** | Compare role/MFA enforcement, storage access and audit trail with platform-admin verification before retiring. |
| `domains/partners.html` | **REVIEW** | Internal partner directory; source indicates partner data is not connected. Implement or retire after confirming intended operator use. |
| `legal/partner-terms.html` | **REDIRECT / ALIAS** | Legacy terms alias; route to partner-standards.html. |
| `partner-agreement.html` | **REVIEW** | Legal framework; legal review required before treating as binding. |
| `partner-standards.html` | **REVIEW** | Standards framework; legal review required before treating as binding. |
| `partner-with-us.html` | **KEEP** | Public partnership introduction. |
| `partner/partner-workspace.html` | **REDIRECT / ALIAS** | Legacy gateway; route to the selected canonical workspace after confirming inbound links. |
| `partner/verification.html` | **ARCHIVE FROM NAV** | Legacy verification gateway; route to onboarding after confirming inbound links. |
| `public/growth/partner-activation.html` | **REVIEW** | Small alias-like page to partner-network; likely consolidate. |
| `public/growth/partner-intelligence.html` | **REVIEW** | Small alias-like page to partner-network; likely consolidate. |
| `public/growth/partner-network.html` | **REVIEW** | Growth/network landing page; clarify distinction from public recruitment page. |
| `public/growth/partner-outreach.html` | **REVIEW** | Small alias-like page to partner-network; likely consolidate. |
| `public/legal/partner-terms.html` | **REDIRECT / ALIAS** | Legacy terms alias; route to partner-standards.html. |
| `public/operations/partner-selection-assignment.html` | **KEEP** | Operations-side partner selection/assignment; separate from partner quote submission. |
| `public/partner-selection-assignment.html` | **REDIRECT / ALIAS** | Existing alias to public/operations/partner-selection-assignment.html. |
| `public/partner/accepted-loads.html` | **KEEP** | Retain as a distinct supporting partner ecosystem page; verify navigation, authorization and actual workflow before launch. |
| `public/partner/api-webhooks.html` | **KEEP** | Partner API/webhook configuration candidate. |
| `public/partner/audit-logs.html` | **ARCHIVE FROM NAV** | ~1 KB workspace-return stub; use security-audit.html. |
| `public/partner/available-loads.html` | **KEEP** | Partner opportunity discovery. |
| `public/partner/bank-account-verification.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated verification workflow. |
| `public/partner/business-verification.html` | **ARCHIVE FROM NAV** | ~1 KB stub; business evidence belongs in onboarding/compliance. |
| `public/partner/capacity-calendar.html` | **ARCHIVE FROM NAV** | ~1 KB stub; consolidate into capacity-resources when calendar workflow exists. |
| `public/partner/capacity-resources.html` | **KEEP** | Partner capacity registration. |
| `public/partner/commercial-rates.html` | **KEEP** | Commercial rates. |
| `public/partner/compliance-evidence.html` | **KEEP** | Partner compliance evidence. |
| `public/partner/compliance-status.html` | **ARCHIVE FROM NAV** | ~1 KB stub; surface status in onboarding/compliance. |
| `public/partner/contract-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated contract workflow. |
| `public/partner/delivery-confirmation.html` | **ARCHIVE FROM NAV** | ~1 KB stub; consolidate into delivery evidence. |
| `public/partner/dispatch-assignment.html` | **KEEP** | Driver dispatch and assignment. |
| `public/partner/dispatch-confirmation.html` | **ARCHIVE FROM NAV** | ~1 KB stub; consolidate into dispatch workflow. |
| `public/partner/dispatch-execution.html` | **ARCHIVE FROM NAV** | ~1 KB stub; implement within dispatch workflow before activation. |
| `public/partner/document-upload.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use documents-delivery-evidence. |
| `public/partner/documents-delivery-evidence.html` | **KEEP** | Documents and proof-of-delivery evidence. |
| `public/partner/driver-invitations.html` | **KEEP** | Driver invitation management. |
| `public/partner/earnings.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated earnings workflow. |
| `public/partner/escrow-ledger.html` | **ARCHIVE FROM NAV** | ~1 KB stub; do not activate escrow without legal and technical approval. |
| `public/partner/export-center.html` | **REVIEW** | Enterprise export concept; verify destination, data scope and authorization before exposure. |
| `public/partner/finance-settlements.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use approved finance experience only. |
| `public/partner/fleet-analytics.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated analytics. |
| `public/partner/fleet-assignment.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use vehicle registry/driver assignment. |
| `public/partner/fleet-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use vehicle registry/capacity resources. |
| `public/partner/freight-invoices.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated invoicing workflow. |
| `public/partner/fuel-advance.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated advance workflow. |
| `public/partner/insurance-claims.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated claims workflow. |
| `public/partner/insurance-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated insurance workflow. |
| `public/partner/integrations-automation.html` | **KEEP** | Canonical integrations and automation UI. |
| `public/partner/invoice-generation.html` | **ARCHIVE FROM NAV** | ~1 KB stub; invoicing requires approved commercial/tax design. |
| `public/partner/load-details.html` | **ARCHIVE FROM NAV** | ~1 KB stub; details should open from available-loads. |
| `public/partner/load-marketplace.html` | **REDIRECT / ALIAS** | Route to public/partner/available-loads.html. |
| `public/partner/multi-entity.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated multi-entity workflow. |
| `public/partner/negotiations.html` | **ARCHIVE FROM NAV** | ~1 KB stub; quote workflow is submit-quote. |
| `public/partner/notifications-support.html` | **KEEP** | Partner notifications and support. |
| `public/partner/offboarding.html` | **KEEP** | Retain as a distinct supporting partner ecosystem page; verify navigation, authorization and actual workflow before launch. |
| `public/partner/partner-directory.html` | **REDIRECT / ALIAS** | Existing alias to public/growth/partner-network.html. |
| `public/partner/partner-onboarding.html` | **KEEP** | Primary multi-step onboarding candidate. |
| `public/partner/partner-profile.html` | **REDIRECT / ALIAS** | Existing alias to public/growth/partner-network.html. |
| `public/partner/partner-support.html` | **ARCHIVE FROM NAV** | Thin support link/redirect; retain only if it routes correctly to create-ticket. |
| `public/partner/payment-disputes.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated dispute workflow. |
| `public/partner/payment-settlements.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated settlement workflow. |
| `public/partner/payout-history.html` | **ARCHIVE FROM NAV** | ~1 KB stub; payout flow not approved. |
| `public/partner/penalties-and-deductions.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated deductions workflow. |
| `public/partner/performance-quality.html` | **REVIEW** | Broad partner scorecard; select canonical implementation only after functional comparison. |
| `public/partner/performance-ratings.html` | **ARCHIVE FROM NAV** | ~1 KB stub; overlaps performance-quality. |
| `public/partner/pickup-confirmation.html` | **KEEP** | Pickup confirmation; inspect linked pickup-tracking dependency. |
| `public/partner/pod-submission.html` | **REDIRECT / ALIAS** | Consolidate with documents-delivery-evidence.html after checking inbound links. |
| `public/partner/pod-upload.html` | **REDIRECT / ALIAS** | Consolidate with documents-delivery-evidence.html after checking inbound links. |
| `public/partner/quote-history.html` | **KEEP** | Partner quote history. |
| `public/partner/rate-cards.html` | **REDIRECT / ALIAS** | Route to public/partner/commercial-rates.html. |
| `public/partner/ratings-performance.html` | **ARCHIVE FROM NAV** | ~1 KB stub; overlaps performance-quality. |
| `public/partner/rbac-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; team access should have one governed implementation. |
| `public/partner/registration.html` | **REDIRECT / ALIAS** | Existing alias to public/partner/partner-onboarding.html. |
| `public/partner/security-audit.html` | **KEEP** | Canonical partner security/audit UI. |
| `public/partner/service-coverage.html` | **KEEP** | Partner service-area submission. |
| `public/partner/services-capabilities.html` | **KEEP** | Partner capability submission. |
| `public/partner/settlements.html` | **KEEP** | Partner-direct payment explanation; align with approved legal model. |
| `public/partner/sla-monitoring.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated SLA monitoring. |
| `public/partner/submit-quote.html` | **KEEP** | Partner quote submission. |
| `public/partner/support-tickets.html` | **REDIRECT / ALIAS** | Route to the canonical support/notifications flow after confirming destination. |
| `public/partner/tax-compliance.html` | **REDIRECT / ALIAS** | Consolidate into compliance evidence or a genuine tax module after requirements review. |
| `public/partner/team-organization.html` | **KEEP** | Partner organization/team management. |
| `public/partner/team-permissions.html` | **KEEP** | Retain as a distinct supporting partner ecosystem page; verify navigation, authorization and actual workflow before launch. |
| `public/partner/telematics-tracking.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated telematics integration. |
| `public/partner/telemetry.html` | **ARCHIVE FROM NAV** | Duplicate placeholder concept. |
| `public/partner/tracking-exceptions.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use carrier exception-reporting. |
| `public/partner/tracking-updates.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use carrier milestone-updates. |
| `public/partner/trip-expenses.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated expense workflow. |
| `public/partner/trip-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; no demonstrated trip workflow. |
| `public/partner/truck-availability.html` | **ARCHIVE FROM NAV** | ~1 KB stub; capacity-resources is canonical candidate. |
| `public/partner/vehicle-management.html` | **ARCHIVE FROM NAV** | ~1 KB stub; use vehicle-registry. |
| `public/partner/white-label.html` | **ARCHIVE FROM NAV** | ~1 KB stub; future enterprise feature, not active partner journey. |
| `public/partners.html` | **REVIEW** | Public partner recruitment/registration; preserve separately from internal domains/partners directory. |
| `public/shipper/partner-bid-status.html` | **KEEP** | Shipper-side bid status; supporting ecosystem. |
| `public/support/partner-complaints.html` | **KEEP** | Partner complaint intake. |
| `src/partner/workspace.html` | **ARCHIVE FROM NAV** | Legacy standalone prototype with illustrative sample data; do not use as production workspace. |
| `workspaces/partner-workspace.html` | **KEEP** | Main Partner Command Centre candidate; verify route and permissions. |

## Canonical journey structure
1. **Discover:** `partner-with-us.html` and `public/partners.html`.
2. **Register and authenticate:** `auth/partner-signup.html`, `auth/partner-signin.html`, `auth/partner-redirect.html`.
3. **Apply and onboard:** `public/partner/partner-onboarding.html`.
4. **Verify and approve:** `app/platform-admin/partner-verification.html`, `partner-compliance.html`, `partner-capabilities.html`, `partner-service-areas.html`.
5. **Enter workspace:** role-specific `app/partner/*/index.html` pages, coordinated through `workspaces/partner-workspace.html` once its canonical routing is confirmed.
6. **Configure capability:** services, coverage, capacity, fleet/vehicles and team.
7. **Find work and quote:** available loads → load details → submit quote → quote history → assignment.
8. **Execute:** driver/vehicle assignment → dispatch → active shipments → milestones → exceptions → pickup/delivery evidence.
9. **Close and improve:** authorized commercial records, performance, support, integrations and security audit.

## Repeated-title groups — explicit decision
| Repeated title | Decision |
|---|---|
| 11 `Index` pages under `app/partner/` | Keep role-specific workspaces; titles are generic but paths and purposes differ. |
| `Partner Workspace` | `workspaces/partner-workspace.html` is canonical candidate; legacy `partner/partner-workspace.html` should become a compatibility redirect after route validation. |
| `Performance Quality` | Keep both temporarily; compare metrics, queries, role guards and intended audience before choosing one canonical view. |
| `Integrations Automation` | Keep public implementation; app path is already a redirect alias. |
| `Security Audit` | Keep public implementation; app path is already a redirect alias. |
| `Partner Verification` | Keep platform-admin page as primary candidate; do not retire control page until MFA/role/audit comparison is complete. |
| `Partners` | Keep both; `domains/partners.html` is internal directory candidate, `public/partners.html` is public recruitment. |
| `Partner Terms` | Keep `partner-standards.html` as canonical standards destination; retain both old terms paths as redirects. |
| `Partner Selection Assignment` | Keep operations implementation; other path is a redirect alias. |

## Cleanup order
1. Confirm canonical routes and page ownership for signup, onboarding and main workspace.
2. Trace inbound links and navigation references for every redirect/archive candidate.
3. Verify role guards, MFA, organization membership, RLS, storage policies and audit logging.
4. Remove placeholder entries from menus and dashboards; replace with clear unavailable/not-yet-enabled states where needed.
5. Add redirects for legacy URLs and test direct navigation, refresh and back-button behavior.
6. Run page-by-page browser and end-to-end tests in owner-restricted staging before considering production.

## Verification limits
- This map is based on source inspection and manifest membership, not a complete runtime dependency graph.
- A small file size or absence of direct `.from()`/`.rpc()` calls is a strong placeholder signal, not conclusive proof that a page is unused.
- No production release, database change, file deletion or live user access test is included.

## Completion checklist
- [ ] Confirm all links and references to pages marked REDIRECT / ALIAS.
- [ ] Confirm all links and references to pages marked ARCHIVE FROM NAV.
- [ ] Compare the two performance pages.
- [ ] Compare both verification interfaces, including MFA and storage permissions.
- [ ] Confirm the canonical workspace route and role routing.
- [ ] Validate partner signup → onboarding → approval → workspace → quote → assignment → shipment → evidence.
- [ ] Re-run the 870-page manifest and verify no broken paths.
- [ ] Obtain explicit owner approval before any physical deletion or production deployment.
