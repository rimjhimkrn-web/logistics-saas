# KRIM Global Logistics — Master Page Register (Repository Inventory)

**Audit date:** 2026-10-24  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Branch:** `main`  
**Inventory tree commit:** `ac0b74a1cfc281691be074d356ee237cc163b15d`  
**Purpose:** Establish a factual inventory before changing routes or deleting pages.

## Important status

This is a **repository file inventory**, not proof that every page is published, linked correctly, functional, secure, or production-ready. No page has been deleted by this inventory. The current tree contains **805 HTML files outside `node_modules/`** and **6 HTML files inside `node_modules/`** (vendor files excluded from the product-page inventory). The total repository tree contains 1305 entries and was not truncated.

The repository has several parallel page families (root-level pages, `public/`, `app/`, `workspaces/`, and `src/`). These are **potential overlap zones**, not automatically confirmed duplicates. Before deleting anything, verify GitHub Pages publishing source, incoming links, redirects, scripts, role behavior, and backend dependencies.

## Canonical user journey (target flow)

1. Public homepage / services / network
2. Access portal
3. Registration or sign-in
4. Role and organization authorization
5. Correct workspace: Customer, Partner, Driver, Warehouse, Customs, Finance, Operations, Enterprise, or Platform Administrator
6. Workflow action (quote, booking, assignment, execution, clearance if required, delivery)
7. Verified payment and financial records where applicable
8. Shipment tracking, evidence, support, and reporting

This is the intended logical flow. Actual page-to-page navigation is **not yet certified** by this inventory.

## Inventory summary

| Repository path family | HTML files |
|---|---:|
| `(repository root)` | 18 |
| `app` | 72 |
| `auth` | 38 |
| `control` | 1 |
| `docs` | 1 |
| `domains` | 13 |
| `legal` | 2 |
| `partner` | 2 |
| `platform` | 1 |
| `public` | 642 |
| `src` | 11 |
| `templates` | 1 |
| `workspaces` | 3 |
| **Total product/repository HTML files (excluding node_modules)** | **805** |
| Excluded vendor HTML files under `node_modules/` | 6 |

## Filename overlap review

Same basenames are useful audit signals, but do not by themselves prove duplication. The following groups need link/dependency review before any retirement:

- **index.html** (18 files): `app/customer/index.html`, `app/customs/index.html`, `app/driver/index.html`, `app/enterprise/index.html`, `app/field/index.html`, `app/finance/index.html`, `app/index.html`, `app/operations/index.html`, `app/partner/index.html`, `app/platform-admin/index.html`, `app/warehouse/index.html`, `docs/legal/index.html`, `index.html`, `public/customer-os/customer-services/index.html`, `public/customer-os/index.html`, `public/customer/index.html`, `public/index.html`, `public/operations/index.html`
- **analytics.html** (5 files): `app/enterprise/analytics.html`, `domains/analytics.html`, `public/customer-os/customer-services/analytics.html`, `public/customer/analytics.html`, `public/warehouse/analytics.html`
- **claims.html** (4 files): `domains/claims.html`, `public/customer-os/customer-services/claims.html`, `public/customer/claims.html`, `public/legal/claims.html`
- **dashboard.html** (4 files): `app/enterprise/dashboard.html`, `dashboard.html`, `public/app/carrier/dashboard.html`, `public/app/shipper/dashboard.html`
- **shipment-details.html** (4 files): `public/customer-os/customer-services/shipment-details.html`, `public/customer/shipment-details.html`, `public/shipments/shipment-details.html`, `public/shipper/shipment-details.html`
- **workspace.html** (4 files): `public/customer-os/customer-services/workspace.html`, `public/customer/workspace.html`, `src/customer/workspace.html`, `src/partner/workspace.html`
- **accounts-payable.html** (3 files): `app/finance/accounts-payable.html`, `public/enterprise/accounts-payable.html`, `public/finance/accounts-payable.html`
- **accounts-receivable.html** (3 files): `app/finance/accounts-receivable.html`, `public/enterprise/accounts-receivable.html`, `public/finance/accounts-receivable.html`
- **contract-management.html** (3 files): `public/customer-os/customer-services/contract-management.html`, `public/customer/contract-management.html`, `public/partner/contract-management.html`
- **contract-rates.html** (3 files): `public/customer-os/quotes-pricing/contract-rates.html`, `public/enterprise/contract-rates.html`, `public/quotes/contract-rates.html`
- **credit-notes.html** (3 files): `public/customer-os/customer-services/credit-notes.html`, `public/customer/credit-notes.html`, `public/finance/credit-notes.html`
- **delivery-confirmation.html** (3 files): `public/customer-os/customer-services/delivery-confirmation.html`, `public/customer/delivery-confirmation.html`, `public/partner/delivery-confirmation.html`
- **forgot-password.html** (3 files): `app/forgot-password.html`, `auth/forgot-password.html`, `forgot-password.html`
- **insurance-claims.html** (3 files): `public/enterprise/insurance-claims.html`, `public/partner/insurance-claims.html`, `public/support/insurance-claims.html`
- **invoices.html** (3 files): `public/customer-os/customer-services/invoices.html`, `public/customer/invoices.html`, `public/shipper/invoices.html`
- **network.html** (3 files): `domains/network.html`, `network.html`, `public/network.html`
- **onboarding.html** (3 files): `public/customer-os/customer-services/onboarding.html`, `public/customer/onboarding.html`, `public/enterprise/onboarding.html`
- **payment-history.html** (3 files): `public/customer-os/customer-services/payment-history.html`, `public/customer/payment-history.html`, `public/finance/payment-history.html`
- **portal.html** (3 files): `portal.html`, `public/portal.html`, `src/enterprise/portal.html`
- **quote-acceptance.html** (3 files): `public/customer-os/quotes-pricing/quote-acceptance.html`, `public/customer/quote-acceptance.html`, `public/quotes/quote-acceptance.html`
- **quote-details.html** (3 files): `public/customer-os/quotes-pricing/quote-details.html`, `public/customer/quote-details.html`, `public/quotes/quote-details.html`
- **tracking.html** (3 files): `domains/tracking.html`, `public/tracking.html`, `tracking.html`
- **verification.html** (3 files): `partner/verification.html`, `public/customer-os/customer-services/verification.html`, `public/customer/verification.html`
- **about.html** (2 files): `about.html`, `public/about.html`
- **address-book.html** (2 files): `public/customer-os/customer-services/address-book.html`, `public/customer/address-book.html`
- **approval-workflows.html** (2 files): `public/customer-os/customer-services/approval-workflows.html`, `public/customer/approval-workflows.html`
- **audit-logs.html** (2 files): `public/finance/audit-logs.html`, `public/partner/audit-logs.html`
- **booking-confirmation.html** (2 files): `public/customer-os/customer-services/booking-confirmation.html`, `public/customer/booking-confirmation.html`
- **capacity-planning.html** (2 files): `app/operations/capacity-planning.html`, `public/operations/capacity-planning.html`
- **cargo-profiles.html** (2 files): `public/customer-os/customer-services/cargo-profiles.html`, `public/customer/cargo-profiles.html`
- **carrier-payables.html** (2 files): `public/billing/carrier-payables.html`, `public/finance/carrier-payables.html`
- **company-profile.html** (2 files): `public/customer-os/customer-services/company-profile.html`, `public/customer/company-profile.html`
- **contact.html** (2 files): `contact.html`, `public/contact.html`
- **control-tower.html** (2 files): `public/app/admin/control-tower.html`, `public/operations/control-tower.html`
- **currency-conversion.html** (2 files): `public/customer-os/quotes-pricing/currency-conversion.html`, `public/quotes/currency-conversion.html`
- **customer-invoices.html** (2 files): `public/billing/customer-invoices.html`, `public/finance/customer-invoices.html`
- **customer-terms.html** (2 files): `legal/customer-terms.html`, `public/legal/customer-terms.html`
- **data-export.html** (2 files): `public/app/data-export.html`, `public/enterprise/data-export.html`
- **dispatch-confirmation.html** (2 files): `public/operations/dispatch-confirmation.html`, `public/partner/dispatch-confirmation.html`
- **dispute.html** (2 files): `public/customer-os/customer-services/dispute.html`, `public/customer/dispute.html`
- **document-upload.html** (2 files): `public/documents/document-upload.html`, `public/partner/document-upload.html`
- **documents.html** (2 files): `app/enterprise/documents.html`, `domains/documents.html`
- **epod-vault.html** (2 files): `public/customer-os/shipper-services/epod-vault.html`, `public/shipper/epod-vault.html`
- **escrow-settlement.html** (2 files): `public/billing/escrow-settlement.html`, `public/enterprise/escrow-settlement.html`
- **finance.html** (2 files): `app/enterprise/finance.html`, `domains/finance.html`
- **help-centre.html** (2 files): `public/app/help-centre.html`, `public/support/help-centre.html`
- **integrations-automation.html** (2 files): `app/partner/integrations-automation.html`, `public/partner/integrations-automation.html`
- **integrations.html** (2 files): `app/enterprise/integrations.html`, `domains/integrations.html`
- **locations.html** (2 files): `public/customer-os/customer-services/locations.html`, `public/customer/locations.html`
- **login.html** (2 files): `auth/login.html`, `public/driver/login.html`
- **notifications.html** (2 files): `public/app/notifications.html`, `public/warehouse/notifications.html`
- **operations-reports.html** (2 files): `app/operations/operations-reports.html`, `public/operations/operations-reports.html`
- **partner-selection-assignment.html** (2 files): `public/operations/partner-selection-assignment.html`, `public/partner-selection-assignment.html`
- **partner-terms.html** (2 files): `legal/partner-terms.html`, `public/legal/partner-terms.html`
- **partner-workspace.html** (2 files): `partner/partner-workspace.html`, `workspaces/partner-workspace.html`
- **partners.html** (2 files): `domains/partners.html`, `public/partners.html`
- **payment-disputes.html** (2 files): `public/partner/payment-disputes.html`, `public/support/payment-disputes.html`
- **payment-verification.html** (2 files): `public/finance/payment-verification.html`, `public/payment-verification.html`
- **pod-capture.html** (2 files): `public/customer-os/customer-services/pod-capture.html`, `public/customer/pod-capture.html`
- **pod-download.html** (2 files): `public/customer-os/customer-services/pod-download.html`, `public/customer/pod-download.html`
- **pod-submission.html** (2 files): `public/driver/pod-submission.html`, `public/partner/pod-submission.html`
- **price-audit.html** (2 files): `public/customer-os/quotes-pricing/price-audit.html`, `public/quotes/price-audit.html`
- **pricing-explanation.html** (2 files): `public/customer-os/quotes-pricing/pricing-explanation.html`, `public/quotes/pricing-explanation.html`
- **privacy.html** (2 files): `privacy.html`, `public/legal/privacy.html`
- **quote-approval.html** (2 files): `public/customer-os/quotes-pricing/quote-approval.html`, `public/quotes/quote-approval.html`
- **quote-expiry.html** (2 files): `public/customer-os/quotes-pricing/quote-expiry.html`, `public/quotes/quote-expiry.html`
- **quote-list.html** (2 files): `public/customer-os/quotes-pricing/quote-list.html`, `public/quotes/quote-list.html`
- **quote-rejection.html** (2 files): `public/customer-os/quotes-pricing/quote-rejection.html`, `public/quotes/quote-rejection.html`
- **quote-revision.html** (2 files): `public/customer-os/quotes-pricing/quote-revision.html`, `public/quotes/quote-revision.html`
- **rate-calculator.html** (2 files): `public/customer-os/shipper-services/rate-calculator.html`, `public/shipper/rate-calculator.html`
- **ratings-reviews.html** (2 files): `public/customer-os/customer-services/ratings-reviews.html`, `public/customer/ratings-reviews.html`
- **recurring-shipments.html** (2 files): `public/customer-os/customer-services/recurring-shipments.html`, `public/customer/recurring-shipments.html`
- **refunds.html** (2 files): `public/customer-os/customer-services/refunds.html`, `public/customer/refunds.html`
- **reorder.html** (2 files): `public/customer-os/customer-services/reorder.html`, `public/customer/reorder.html`
- **reports.html** (2 files): `public/customer-os/customer-services/reports.html`, `public/customer/reports.html`
- **reset-password.html** (2 files): `app/reset-password.html`, `auth/reset-password.html`
- **returns.html** (2 files): `public/customer-os/customer-services/returns.html`, `public/customer/returns.html`
- **route-planning.html** (2 files): `app/operations/route-planning.html`, `public/shipments/route-planning.html`
- **saved-routes.html** (2 files): `public/customer-os/customer-services/saved-routes.html`, `public/customer/saved-routes.html`
- **security-audit.html** (2 files): `app/partner/security-audit.html`, `public/partner/security-audit.html`
- **settlement.html** (2 files): `public/customer-os/customer-services/settlement.html`, `public/customer/settlement.html`
- **shipment-create.html** (2 files): `public/customer/shipment-create.html`, `public/shipments/shipment-create.html`
- **shipment-timeline.html** (2 files): `public/customer-os/customer-services/shipment-timeline.html`, `public/customer/shipment-timeline.html`
- **shipments.html** (2 files): `app/enterprise/shipments.html`, `domains/shipments.html`
- **shipping-preferences.html** (2 files): `public/customer-os/customer-services/shipping-preferences.html`, `public/customer/shipping-preferences.html`
- **spot-approvals.html** (2 files): `public/customer-os/shipper-services/spot-approvals.html`, `public/shipper/spot-approvals.html`
- **spot-pricing.html** (2 files): `public/customer-os/quotes-pricing/spot-pricing.html`, `public/quotes/spot-pricing.html`
- **support.html** (2 files): `public/customer-os/customer-services/support.html`, `public/customer/support.html`
- **tax-compliance.html** (2 files): `app/finance/tax-compliance.html`, `public/partner/tax-compliance.html`
- **team-members.html** (2 files): `public/customer-os/customer-services/team-members.html`, `public/customer/team-members.html`
- **terms.html** (2 files): `public/legal/terms.html`, `terms.html`
- **tracking-map.html** (2 files): `public/customer-os/customer-services/tracking-map.html`, `public/customer/tracking-map.html`

## Full HTML file inventory

### (repository root) (18)

- `about.html`
- `admin-control-center.html`
- `admin-login.html`
- `admin.html`
- `contact.html`
- `dashboard.html`
- `financial-management.html`
- `forgot-password.html`
- `global-markets.html`
- `home-v2.html`
- `index.html`
- `network.html`
- `platform.html`
- `portal.html`
- `privacy.html`
- `refund.html`
- `terms.html`
- `tracking.html`

### app (72)

- `app/customer/index.html`
- `app/customs/index.html`
- `app/driver/index.html`
- `app/driver/module-01-assignment-inbox.html`
- `app/driver/module-02-assignment-details.html`
- `app/driver/module-03-assignment-acceptance.html`
- `app/driver/module-04-driver-vehicle-readiness.html`
- `app/driver/module-05-pickup-collection.html`
- `app/driver/module-06-shipment-milestones.html`
- `app/driver/module-07-route-stop-management.html`
- `app/driver/module-08-live-tracking.html`
- `app/driver/module-09-exceptions-incidents.html`
- `app/driver/module-10-proof-of-delivery.html`
- `app/driver/module-11-failed-delivery-returns.html`
- `app/driver/module-12-delivery-history.html`
- `app/driver/module-13-earnings-settlements.html`
- `app/driver/module-14-performance-quality.html`
- `app/driver/module-15-notifications-support.html`
- `app/driver/module-16-driver-profile-compliance.html`
- `app/driver/module-17-security-audit.html`
- `app/enterprise/ai-governance.html`
- `app/enterprise/analytics.html`
- `app/enterprise/approvals.html`
- `app/enterprise/automation.html`
- `app/enterprise/commercial.html`
- `app/enterprise/dashboard.html`
- `app/enterprise/documents.html`
- `app/enterprise/finance.html`
- `app/enterprise/index.html`
- `app/enterprise/institutional-memory.html`
- `app/enterprise/integrations.html`
- `app/enterprise/organization.html`
- `app/enterprise/risk-compliance.html`
- `app/enterprise/shipments.html`
- `app/field/index.html`
- `app/finance/accounts-payable.html`
- `app/finance/accounts-receivable.html`
- `app/finance/financial-reporting.html`
- `app/finance/index.html`
- `app/finance/invoicing.html`
- `app/finance/multi-currency.html`
- `app/finance/partner-settlements.html`
- `app/finance/payment-processing.html`
- `app/finance/refunds-disputes.html`
- `app/finance/revenue-commission.html`
- `app/finance/tax-compliance.html`
- `app/finance/treasury-audit.html`
- `app/forgot-password.html`
- `app/index.html`
- `app/operations/capacity-planning.html`
- `app/operations/carrier-coordination.html`
- `app/operations/customs-readiness.html`
- `app/operations/dispatch-control.html`
- `app/operations/exception-management.html`
- `app/operations/index.html`
- `app/operations/operations-reporting-export.html`
- `app/operations/operations-reports.html`
- `app/operations/operations-security-audit.html`
- `app/operations/operations-security.html`
- `app/operations/route-planning.html`
- `app/operations/service-performance.html`
- `app/operations/shipment-control.html`
- `app/operations/tracking-activity.html`
- `app/operations/warehouse-coordination.html`
- `app/partner/index.html`
- `app/partner/integrations-automation.html`
- `app/partner/security-audit.html`
- `app/platform-admin/index.html`
- `app/register.html`
- `app/reset-password.html`
- `app/sign-in.html`
- `app/warehouse/index.html`

### auth (38)

- `auth/access.html`
- `auth/account-deactivation.html`
- `auth/account-deletion.html`
- `auth/account-recovery-status.html`
- `auth/active-sessions.html`
- `auth/auth-callback.html`
- `auth/backup-codes.html`
- `auth/change-email.html`
- `auth/change-password.html`
- `auth/change-phone.html`
- `auth/consent-management.html`
- `auth/device-management.html`
- `auth/disabled.html`
- `auth/driver-access.html`
- `auth/driver-signin.html`
- `auth/driver-signup.html`
- `auth/forgot-password.html`
- `auth/identity-verification.html`
- `auth/invitation.html`
- `auth/krim-admin-access.html`
- `auth/login.html`
- `auth/logout.html`
- `auth/mfa-challenge.html`
- `auth/mfa-enroll.html`
- `auth/mfa.html`
- `auth/organization-invitation-acceptance.html`
- `auth/organization-switch.html`
- `auth/partner-redirect.html`
- `auth/partner-signin.html`
- `auth/partner-signup.html`
- `auth/passkey-management.html`
- `auth/recovery.html`
- `auth/reset-password.html`
- `auth/session-expired.html`
- `auth/signup.html`
- `auth/step-up-verification.html`
- `auth/verify-email.html`
- `auth/verify-phone.html`

### control (1)

- `control/partner-verification.html`

### docs (1)

- `docs/legal/index.html`

### domains (13)

- `domains/ai.html`
- `domains/analytics.html`
- `domains/capacity.html`
- `domains/claims.html`
- `domains/compliance.html`
- `domains/documents.html`
- `domains/exceptions.html`
- `domains/finance.html`
- `domains/integrations.html`
- `domains/network.html`
- `domains/partners.html`
- `domains/shipments.html`
- `domains/tracking.html`

### legal (2)

- `legal/customer-terms.html`
- `legal/partner-terms.html`

### partner (2)

- `partner/partner-workspace.html`
- `partner/verification.html`

### platform (1)

- `platform/krim-platform-shell.html`

### public (642)

- `public/404.html`
- `public/about.html`
- `public/admin/customer-ecosystem-os.html`
- `public/admin/kms-key-rotation.html`
- `public/admin/platform-health.html`
- `public/admin/rbac-matrix.html`
- `public/admin/security-desk.html`
- `public/admin/siem-audit-logs.html`
- `public/admin/tenant-partitioning.html`
- `public/ai-ops/dynamic-pricing.html`
- `public/ai-ops/predictive-maintenance.html`
- `public/ai-ops/route-optimizer.html`
- `public/ai/ai-audit-history.html`
- `public/ai/assistant.html`
- `public/ai/capacity-forecasting.html`
- `public/ai/carrier-recommendations.html`
- `public/ai/compliance-assistant.html`
- `public/ai/conversation-history.html`
- `public/ai/customer-support-assistant.html`
- `public/ai/delay-risk.html`
- `public/ai/demand-forecasting.html`
- `public/ai/document-extraction.html`
- `public/ai/eta-intelligence.html`
- `public/ai/evaluation-results.html`
- `public/ai/finance-assistant.html`
- `public/ai/human-review-queue.html`
- `public/ai/maintenance-predictions.html`
- `public/ai/model-management.html`
- `public/ai/pricing-recommendations.html`
- `public/ai/prompt-governance.html`
- `public/ai/route-recommendations.html`
- `public/ai/shipment-planning.html`
- `public/ai/warehouse-forecasting.html`
- `public/air.html`
- `public/analytics/carbon-calculator.html`
- `public/analytics/carbon-offset-market.html`
- `public/analytics/carrier-scorecard.html`
- `public/analytics/esg-compliance-report.html`
- `public/analytics/executive-bi-dashboard.html`
- `public/analytics/lane-analytics.html`
- `public/app/accessibility-settings.html`
- `public/app/account-overview.html`
- `public/app/activity-history.html`
- `public/app/admin/control-tower.html`
- `public/app/app-settings.html`
- `public/app/app-shell.html`
- `public/app/carrier/dashboard.html`
- `public/app/command-palette.html`
- `public/app/connected-applications.html`
- `public/app/dashboard-framework.html`
- `public/app/data-export.html`
- `public/app/document-vault.html`
- `public/app/error-centre.html`
- `public/app/global-search.html`
- `public/app/help-centre.html`
- `public/app/messaging-center.html`
- `public/app/notifications.html`
- `public/app/offline-queue.html`
- `public/app/org-switcher.html`
- `public/app/preferences.html`
- `public/app/privacy-controls.html`
- `public/app/profile-settings.html`
- `public/app/shared/dashboard-shell.html`
- `public/app/shared/organization-switcher.html`
- `public/app/shared/security-manager.html`
- `public/app/shipper/dashboard.html`
- `public/app/sync-status.html`
- `public/billing/carrier-payables.html`
- `public/billing/customer-invoices.html`
- `public/billing/escrow-settlement.html`
- `public/billing/financial-ledger-audit.html`
- `public/billing/freight-audit-disputes.html`
- `public/billing/freight-rating-engine.html`
- `public/compliance/customs-audit-ledger.html`
- `public/compliance/dangerous-goods-decl.html`
- `public/compliance/electronic-bl.html`
- `public/compliance/hs-code-classifier.html`
- `public/compliance/single-window-customs.html`
- `public/compliance/trade-sanctions-screening.html`
- `public/connectors/ais-vessel-stream.html`
- `public/connectors/erp-adapters.html`
- `public/connectors/iot-container-sensors.html`
- `public/connectors/port-edi-gateway.html`
- `public/contact.html`
- `public/control-centre/digital-twin-map.html`
- `public/control-centre/exception-dispatch.html`
- `public/control-centre/facility-matrix.html`
- `public/control-centre/simulation-room.html`
- `public/country-guides.html`
- `public/customer-os/INTEGRATION-MANIFEST.html`
- `public/customer-os/customer-services/address-book.html`
- `public/customer-os/customer-services/analytics.html`
- `public/customer-os/customer-services/approval-workflows.html`
- `public/customer-os/customer-services/booking-confirmation.html`
- `public/customer-os/customer-services/cargo-profiles.html`
- `public/customer-os/customer-services/claims.html`
- `public/customer-os/customer-services/company-profile.html`
- `public/customer-os/customer-services/contract-management.html`
- `public/customer-os/customer-services/credit-notes.html`
- `public/customer-os/customer-services/delivery-confirmation.html`
- `public/customer-os/customer-services/dispute.html`
- `public/customer-os/customer-services/index.html`
- `public/customer-os/customer-services/invoices.html`
- `public/customer-os/customer-services/locations.html`
- `public/customer-os/customer-services/onboarding.html`
- `public/customer-os/customer-services/payment-history.html`
- `public/customer-os/customer-services/pod-capture.html`
- `public/customer-os/customer-services/pod-download.html`
- `public/customer-os/customer-services/ratings-reviews.html`
- `public/customer-os/customer-services/recurring-shipments.html`
- `public/customer-os/customer-services/refunds.html`
- `public/customer-os/customer-services/reorder.html`
- `public/customer-os/customer-services/reports.html`
- `public/customer-os/customer-services/returns.html`
- `public/customer-os/customer-services/saved-routes.html`
- `public/customer-os/customer-services/settlement.html`
- `public/customer-os/customer-services/shipment-details.html`
- `public/customer-os/customer-services/shipment-list.html`
- `public/customer-os/customer-services/shipment-timeline.html`
- `public/customer-os/customer-services/shipping-preferences.html`
- `public/customer-os/customer-services/support.html`
- `public/customer-os/customer-services/team-members.html`
- `public/customer-os/customer-services/tracking-map.html`
- `public/customer-os/customer-services/verification.html`
- `public/customer-os/customer-services/workspace.html`
- `public/customer-os/index.html`
- `public/customer-os/quotes-pricing/contract-rates.html`
- `public/customer-os/quotes-pricing/currency-conversion.html`
- `public/customer-os/quotes-pricing/price-audit.html`
- `public/customer-os/quotes-pricing/pricing-explanation.html`
- `public/customer-os/quotes-pricing/quote-acceptance.html`
- `public/customer-os/quotes-pricing/quote-approval.html`
- `public/customer-os/quotes-pricing/quote-details.html`
- `public/customer-os/quotes-pricing/quote-expiry.html`
- `public/customer-os/quotes-pricing/quote-list.html`
- `public/customer-os/quotes-pricing/quote-rejection.html`
- `public/customer-os/quotes-pricing/quote-revision.html`
- `public/customer-os/quotes-pricing/spot-pricing.html`
- `public/customer-os/shipper-services/epod-vault.html`
- `public/customer-os/shipper-services/rate-calculator.html`
- `public/customer-os/shipper-services/spot-approvals.html`
- `public/customer/address-book.html`
- `public/customer/analytics.html`
- `public/customer/approval-workflows.html`
- `public/customer/booking-confirmation.html`
- `public/customer/cargo-profiles.html`
- `public/customer/claims.html`
- `public/customer/company-profile.html`
- `public/customer/contract-management.html`
- `public/customer/credit-notes.html`
- `public/customer/delivery-confirmation.html`
- `public/customer/dispute.html`
- `public/customer/index.html`
- `public/customer/invoices.html`
- `public/customer/locations.html`
- `public/customer/onboarding.html`
- `public/customer/payment-history.html`
- `public/customer/pod-capture.html`
- `public/customer/pod-download.html`
- `public/customer/portal-overview.html`
- `public/customer/quote-acceptance.html`
- `public/customer/quote-details.html`
- `public/customer/quote-request.html`
- `public/customer/ratings-reviews.html`
- `public/customer/recurring-shipments.html`
- `public/customer/refunds.html`
- `public/customer/reorder.html`
- `public/customer/reports.html`
- `public/customer/returns.html`
- `public/customer/saved-routes.html`
- `public/customer/settlement.html`
- `public/customer/shipment-create.html`
- `public/customer/shipment-details.html`
- `public/customer/shipment-timeline.html`
- `public/customer/shipping-preferences.html`
- `public/customer/support.html`
- `public/customer/team-members.html`
- `public/customer/tracking-map.html`
- `public/customer/verification.html`
- `public/customer/workflow-hub.html`
- `public/customer/workspace.html`
- `public/developer/api-docs.html`
- `public/developer/api-key-management.html`
- `public/developer/app-registration.html`
- `public/developer/rate-limit-telemetry.html`
- `public/developer/sdk-downloads.html`
- `public/developer/webhooks-management.html`
- `public/documents/consignment-notes.html`
- `public/documents/delivery-receipts.html`
- `public/documents/digital-signatures.html`
- `public/documents/document-approval.html`
- `public/documents/document-details.html`
- `public/documents/document-download.html`
- `public/documents/document-expiry.html`
- `public/documents/document-list.html`
- `public/documents/document-retention.html`
- `public/documents/document-review.html`
- `public/documents/document-sharing.html`
- `public/documents/document-upload.html`
- `public/documents/document-version-history.html`
- `public/documents/insurance-certificates.html`
- `public/documents/international-trade-documents.html`
- `public/documents/transport-licences.html`
- `public/driver/assigned-trips.html`
- `public/driver/assignment-details.html`
- `public/driver/assignment-inbox.html`
- `public/driver/cargo-condition.html`
- `public/driver/delay-report.html`
- `public/driver/delivery-checklist.html`
- `public/driver/driver-earnings.html`
- `public/driver/driver-settings.html`
- `public/driver/emergency-support.html`
- `public/driver/expense-submission.html`
- `public/driver/failed-delivery.html`
- `public/driver/incident-report.html`
- `public/driver/loading-confirmation.html`
- `public/driver/location-sharing.html`
- `public/driver/login.html`
- `public/driver/maintenance-log.html`
- `public/driver/offline-sync.html`
- `public/driver/performance-metrics.html`
- `public/driver/photo-proof.html`
- `public/driver/pickup-checklist.html`
- `public/driver/pod-submission.html`
- `public/driver/pod-summary.html`
- `public/driver/profile.html`
- `public/driver/recipient-verification.html`
- `public/driver/return-trip.html`
- `public/driver/route-navigation.html`
- `public/driver/safety-checklist.html`
- `public/driver/signature-capture.html`
- `public/driver/support-center.html`
- `public/driver/trip-completion.html`
- `public/driver/trip-details.html`
- `public/driver/trip-status.html`
- `public/enterprise.html`
- `public/enterprise/accounts-payable.html`
- `public/enterprise/accounts-receivable.html`
- `public/enterprise/approval-matrix.html`
- `public/enterprise/audit-logging.html`
- `public/enterprise/billing-consolidation.html`
- `public/enterprise/budget-controls.html`
- `public/enterprise/business-units.html`
- `public/enterprise/carbon-reporting.html`
- `public/enterprise/carrier-sla.html`
- `public/enterprise/company-verification.html`
- `public/enterprise/contract-rates.html`
- `public/enterprise/cost-centres.html`
- `public/enterprise/credit-risk.html`
- `public/enterprise/currency-hedging.html`
- `public/enterprise/customs-compliance.html`
- `public/enterprise/data-export.html`
- `public/enterprise/enterprise-audit-log.html`
- `public/enterprise/enterprise-overview.html`
- `public/enterprise/enterprise-summary.html`
- `public/enterprise/erp-integrations.html`
- `public/enterprise/escrow-settlement.html`
- `public/enterprise/exception-escalations.html`
- `public/enterprise/exception-handling.html`
- `public/enterprise/fleet-telematics.html`
- `public/enterprise/freight-audit.html`
- `public/enterprise/general-ledger.html`
- `public/enterprise/insurance-claims.html`
- `public/enterprise/locations-and-facilities.html`
- `public/enterprise/onboarding.html`
- `public/enterprise/organization-settings.html`
- `public/enterprise/procurement.html`
- `public/enterprise/purchase-orders.html`
- `public/enterprise/reconciliation.html`
- `public/enterprise/retention-policy.html`
- `public/enterprise/role-management.html`
- `public/enterprise/service-review.html`
- `public/enterprise/shipping-policy.html`
- `public/enterprise/sla-governance.html`
- `public/enterprise/sla-reports.html`
- `public/enterprise/tax-engine.html`
- `public/enterprise/team-directory.html`
- `public/enterprise/tenant-governance.html`
- `public/enterprise/tenant-quotas.html`
- `public/enterprise/tender-management.html`
- `public/enterprise/three-way-matching.html`
- `public/enterprise/volume-commitments.html`
- `public/enterprise/vpc-configuration.html`
- `public/enterprise/working-capital.html`
- `public/express.html`
- `public/finance/accounts-payable.html`
- `public/finance/accounts-receivable.html`
- `public/finance/api-keys.html`
- `public/finance/audit-logs.html`
- `public/finance/bank-accounts.html`
- `public/finance/bank-reconciliation.html`
- `public/finance/carrier-payables.html`
- `public/finance/cash-flow-forecast.html`
- `public/finance/compliance-rules.html`
- `public/finance/credit-notes.html`
- `public/finance/customer-invoices.html`
- `public/finance/dispute-management.html`
- `public/finance/executive-dashboard.html`
- `public/finance/expense-reports.html`
- `public/finance/finance-dashboard.html`
- `public/finance/financial-consolidation.html`
- `public/finance/fraud-prevention.html`
- `public/finance/fx-hedging.html`
- `public/finance/invoice-details.html`
- `public/finance/liquidity-overview.html`
- `public/finance/merchant-accounts.html`
- `public/finance/payment-gateways.html`
- `public/finance/payment-history.html`
- `public/finance/payment-methods.html`
- `public/finance/payment-result.html`
- `public/finance/payment-verification.html`
- `public/finance/refund-requests.html`
- `public/finance/refund-status.html`
- `public/finance/revenue-reports.html`
- `public/finance/sweep-rules.html`
- `public/finance/tax-invoices.html`
- `public/finance/tax-settings.html`
- `public/finance/transaction-details.html`
- `public/finance/transaction-fees.html`
- `public/finance/treasury-dashboard.html`
- `public/finance/webhooks.html`
- `public/freight/booking-management.html`
- `public/freight/broker-management.html`
- `public/freight/carrier-bookings.html`
- `public/freight/consolidation.html`
- `public/freight/container-bookings.html`
- `public/freight/customs-declarations.html`
- `public/freight/deconsolidation.html`
- `public/freight/demurrage-detention.html`
- `public/freight/duty-calculator.html`
- `public/freight/export-controls.html`
- `public/freight/export-management.html`
- `public/freight/forwarder-dashboard.html`
- `public/freight/forwarder-onboarding.html`
- `public/freight/forwarder-settlement.html`
- `public/freight/forwarding-quote.html`
- `public/freight/free-trade-zones.html`
- `public/freight/house-bills.html`
- `public/freight/hs-code-management.html`
- `public/freight/import-management.html`
- `public/freight/master-bills.html`
- `public/freight/origin-qualification.html`
- `public/freight/regulatory-audits.html`
- `public/freight/sanctions-screening.html`
- `public/freight/shipping-instructions.html`
- `public/freight/trade-dashboard.html`
- `public/freight/transshipment.html`
- `public/get-started.html`
- `public/global-coverage.html`
- `public/global-operations/business-continuity.html`
- `public/global-operations/cargo-claims-disputes.html`
- `public/global-operations/carrier-contracts.html`
- `public/global-operations/customer-support-cases.html`
- `public/global-operations/fleet-maintenance.html`
- `public/global-operations/landed-cost.html`
- `public/global-operations/market-regulatory-config.html`
- `public/global-operations/network-coverage.html`
- `public/global-operations/order-fulfilment.html`
- `public/global-operations/reverse-logistics.html`
- `public/global-operations/trade-document-packs.html`
- `public/global-operations/trade-lane-management.html`
- `public/global-workflows.html`
- `public/growth/acquisition-command.html`
- `public/growth/acquisition-performance.html`
- `public/growth/automation-command.html`
- `public/growth/customer-acquisition.html`
- `public/growth/customer-conversion.html`
- `public/growth/customer-retention.html`
- `public/growth/discovery-workbench.html`
- `public/growth/intelligence-analytics.html`
- `public/growth/multi-market-governance.html`
- `public/growth/network-gap-analyzer.html`
- `public/growth/onboarding-tracker.html`
- `public/growth/partner-activation.html`
- `public/growth/partner-intelligence.html`
- `public/growth/partner-outreach.html`
- `public/growth/prospect-registry.html`
- `public/growth/prospect-review.html`
- `public/growth/resilience-command.html`
- `public/growth/shipment-matching.html`
- `public/growth/signal-intake.html`
- `public/growth/source-governance.html`
- `public/guides.html`
- `public/index.html`
- `public/industries.html`
- `public/knowledge.html`
- `public/legal/acceptable-use.html`
- `public/legal/ai-policy.html`
- `public/legal/claims.html`
- `public/legal/cookie-policy.html`
- `public/legal/customer-terms.html`
- `public/legal/dangerous-goods.html`
- `public/legal/data-retention.html`
- `public/legal/electronic-communications.html`
- `public/legal/enterprise-terms.html`
- `public/legal/partner-terms.html`
- `public/legal/payment-policy.html`
- `public/legal/privacy.html`
- `public/legal/prohibited-goods.html`
- `public/legal/refund-policy.html`
- `public/legal/shipping-terms.html`
- `public/legal/terms.html`
- `public/logistics-glossary.html`
- `public/network.html`
- `public/ocean.html`
- `public/offline.html`
- `public/operations/active-disruptions.html`
- `public/operations/autonomous-reroute.html`
- `public/operations/capacity-planning.html`
- `public/operations/carrier-matching.html`
- `public/operations/control-room-handover.html`
- `public/operations/control-tower.html`
- `public/operations/delivery-monitoring.html`
- `public/operations/dispatch-confirmation.html`
- `public/operations/dispatch-queue.html`
- `public/operations/eta-predictor.html`
- `public/operations/exception-desk.html`
- `public/operations/incident-management.html`
- `public/operations/index.html`
- `public/operations/late-shipment-management.html`
- `public/operations/load-planning.html`
- `public/operations/missed-milestones.html`
- `public/operations/operational-audit-desk.html`
- `public/operations/operations-dashboard.html`
- `public/operations/operations-reports.html`
- `public/operations/partner-selection-assignment.html`
- `public/operations/pickup-monitoring.html`
- `public/operations/rerouting-approvals.html`
- `public/operations/route-planner.html`
- `public/operations/service-level-monitoring.html`
- `public/operations/trip-monitoring.html`
- `public/operations/vehicle-capacity.html`
- `public/partner-selection-assignment.html`
- `public/partner/accepted-loads.html`
- `public/partner/api-webhooks.html`
- `public/partner/audit-logs.html`
- `public/partner/available-loads.html`
- `public/partner/bank-account-verification.html`
- `public/partner/business-verification.html`
- `public/partner/capacity-calendar.html`
- `public/partner/capacity-resources.html`
- `public/partner/commercial-rates.html`
- `public/partner/compliance-status.html`
- `public/partner/contract-management.html`
- `public/partner/delivery-confirmation.html`
- `public/partner/dispatch-assignment.html`
- `public/partner/dispatch-confirmation.html`
- `public/partner/dispatch-execution.html`
- `public/partner/document-upload.html`
- `public/partner/documents-delivery-evidence.html`
- `public/partner/driver-management.html`
- `public/partner/earnings.html`
- `public/partner/escrow-ledger.html`
- `public/partner/export-center.html`
- `public/partner/finance-settlements.html`
- `public/partner/fleet-analytics.html`
- `public/partner/fleet-assignment.html`
- `public/partner/fleet-management.html`
- `public/partner/freight-invoices.html`
- `public/partner/fuel-advance.html`
- `public/partner/insurance-claims.html`
- `public/partner/insurance-management.html`
- `public/partner/integrations-automation.html`
- `public/partner/invoice-generation.html`
- `public/partner/load-details.html`
- `public/partner/load-marketplace.html`
- `public/partner/multi-entity.html`
- `public/partner/negotiations.html`
- `public/partner/notifications-support.html`
- `public/partner/offboarding.html`
- `public/partner/partner-directory.html`
- `public/partner/partner-onboarding.html`
- `public/partner/partner-profile.html`
- `public/partner/partner-support.html`
- `public/partner/payment-disputes.html`
- `public/partner/payment-settlements.html`
- `public/partner/payout-history.html`
- `public/partner/penalties-and-deductions.html`
- `public/partner/performance-quality.html`
- `public/partner/performance-ratings.html`
- `public/partner/pickup-confirmation.html`
- `public/partner/pod-submission.html`
- `public/partner/pod-upload.html`
- `public/partner/quote-history.html`
- `public/partner/rate-cards.html`
- `public/partner/ratings-performance.html`
- `public/partner/rbac-management.html`
- `public/partner/registration.html`
- `public/partner/security-audit.html`
- `public/partner/service-coverage.html`
- `public/partner/services-capabilities.html`
- `public/partner/settlements.html`
- `public/partner/sla-monitoring.html`
- `public/partner/submit-quote.html`
- `public/partner/support-tickets.html`
- `public/partner/tax-compliance.html`
- `public/partner/team-organization.html`
- `public/partner/team-permissions.html`
- `public/partner/telematics-tracking.html`
- `public/partner/telemetry.html`
- `public/partner/tracking-exceptions.html`
- `public/partner/tracking-updates.html`
- `public/partner/trip-expenses.html`
- `public/partner/trip-management.html`
- `public/partner/truck-availability.html`
- `public/partner/vehicle-management.html`
- `public/partner/white-label.html`
- `public/partners.html`
- `public/payment-verification.html`
- `public/pickup-tracking.html`
- `public/portal.html`
- `public/production/deployment-manifest.html`
- `public/production/master-freeze-seal.html`
- `public/production/security-hardening.html`
- `public/quote-result.html`
- `public/quote.html`
- `public/quotes/contract-rates.html`
- `public/quotes/currency-conversion.html`
- `public/quotes/price-audit.html`
- `public/quotes/pricing-explanation.html`
- `public/quotes/quote-acceptance.html`
- `public/quotes/quote-approval.html`
- `public/quotes/quote-details.html`
- `public/quotes/quote-expiry.html`
- `public/quotes/quote-list.html`
- `public/quotes/quote-rejection.html`
- `public/quotes/quote-revision.html`
- `public/quotes/spot-pricing.html`
- `public/quotes/surcharges.html`
- `public/quotes/tax-estimation.html`
- `public/resources.html`
- `public/road-rail.html`
- `public/shipment-confirmation.html`
- `public/shipments/cancellation.html`
- `public/shipments/cargo-details.html`
- `public/shipments/carrier-assignment.html`
- `public/shipments/delivery.html`
- `public/shipments/dispatch.html`
- `public/shipments/milestones.html`
- `public/shipments/pickup.html`
- `public/shipments/proof-of-delivery.html`
- `public/shipments/route-planning.html`
- `public/shipments/shipment-analytics.html`
- `public/shipments/shipment-audit-log.html`
- `public/shipments/shipment-create.html`
- `public/shipments/shipment-details.html`
- `public/shipments/shipment-documents.html`
- `public/shipments/shipment-edit.html`
- `public/shipments/shipment-exceptions.html`
- `public/shipments/shipment-export.html`
- `public/shipments/shipment-financials.html`
- `public/shipments/shipment-parties.html`
- `public/shipments/shipment-settings.html`
- `public/shipments/tracking-events.html`
- `public/shipments/transport-legs.html`
- `public/shipper/active-shipments.html`
- `public/shipper/booking-request.html`
- `public/shipper/coverage-review.html`
- `public/shipper/epod-vault.html`
- `public/shipper/invoices.html`
- `public/shipper/payment-checkout.html`
- `public/shipper/quote-comparison.html`
- `public/shipper/rate-calculator.html`
- `public/shipper/shipment-details.html`
- `public/shipper/spot-approvals.html`
- `public/shipper/support-claims.html`
- `public/shipping-guides.html`
- `public/solutions.html`
- `public/status.html`
- `public/support/compensation-review.html`
- `public/support/create-ticket.html`
- `public/support/customer-complaints.html`
- `public/support/damage-claims.html`
- `public/support/help-centre.html`
- `public/support/insurance-claims.html`
- `public/support/knowledge-base.html`
- `public/support/late-delivery-claims.html`
- `public/support/loss-claims.html`
- `public/support/notifications-dispatch.html`
- `public/support/partner-complaints.html`
- `public/support/payment-disputes.html`
- `public/support/priority-escalation.html`
- `public/support/refund-disputes.html`
- `public/support/resolution-confirmation.html`
- `public/support/service-status.html`
- `public/support/shipment-claims.html`
- `public/support/ticket-desk.html`
- `public/support/ticket-details.html`
- `public/support/ticket-history.html`
- `public/testing/api-contract-audit.html`
- `public/testing/chaos-resilience.html`
- `public/testing/e2e-test-runner.html`
- `public/tracking.html`
- `public/trade-guides.html`
- `public/visibility/air-cargo-tracking.html`
- `public/visibility/container-condition.html`
- `public/visibility/customer-alert-preferences.html`
- `public/visibility/delay-predictions.html`
- `public/visibility/eta-details.html`
- `public/visibility/geofence-events.html`
- `public/visibility/live-tracking-map.html`
- `public/visibility/milestone-timeline.html`
- `public/visibility/rail-tracking.html`
- `public/visibility/road-tracking.html`
- `public/visibility/route-deviations.html`
- `public/visibility/temperature-monitoring.html`
- `public/visibility/tracking-history.html`
- `public/visibility/tracking-sharing.html`
- `public/visibility/vessel-tracking.html`
- `public/warehouse/access-audit.html`
- `public/warehouse/analytics.html`
- `public/warehouse/appointment-calendar.html`
- `public/warehouse/container-management.html`
- `public/warehouse/cross-docking.html`
- `public/warehouse/cycle-counting.html`
- `public/warehouse/damage-exceptions.html`
- `public/warehouse/dispatch-handover.html`
- `public/warehouse/dock-scheduling.html`
- `public/warehouse/facility-capacity.html`
- `public/warehouse/facility-management.html`
- `public/warehouse/facility-onboarding.html`
- `public/warehouse/facility-profile.html`
- `public/warehouse/goods-receipt.html`
- `public/warehouse/inbound-receiving.html`
- `public/warehouse/inventory-ledger.html`
- `public/warehouse/inventory.html`
- `public/warehouse/labor-management.html`
- `public/warehouse/notifications.html`
- `public/warehouse/outbound-dispatch.html`
- `public/warehouse/packing.html`
- `public/warehouse/picking-packing.html`
- `public/warehouse/picking.html`
- `public/warehouse/putaway-storage.html`
- `public/warehouse/putaway.html`
- `public/warehouse/quality-control.html`
- `public/warehouse/returns-rma.html`
- `public/warehouse/stock-movements.html`
- `public/warehouse/warehouse-dashboard.html`
- `public/warehouse/warehouse-evidence.html`
- `public/warehouse/warehouse-performance.html`
- `public/warehouse/yard-management.html`
- `public/warehousing.html`

### src (11)

- `src/admin/control_tower.html`
- `src/auth/unified_gateway.html`
- `src/customer/workspace.html`
- `src/document_vault.html`
- `src/driver/app.html`
- `src/enterprise/portal.html`
- `src/financial_hub.html`
- `src/partner/workspace.html`
- `src/shipments/details.html`
- `src/shipments/list.html`
- `src/telemetry_center.html`

### templates (1)

- `templates/krim-connected-page.html`

### workspaces (3)

- `workspaces/customer-workspace.html`
- `workspaces/operations-workspace.html`
- `workspaces/partner-workspace.html`

## Integration work started — 2026-10-24

The canonical route registry is now available in `config.js` as `window.KRIM_ROUTES`, with `window.krimRoute(name, query)` for root-aware URLs. `auth/login.html` uses the registry for the eight standard workspaces while retaining membership and MFA checks.

- Integration status: [KRIM end-to-end integration status](KRIM-END-TO-END-INTEGRATION-STATUS.md)
- Static local-link audit: `scripts/audit-krim-links.mjs`
- Automated GitHub Actions audit: `.github/workflows/krim-static-link-audit.yml`

This is the first integration batch only. The registry does not magically connect every existing HTML page, and the automated audit has not yet produced a verified report. Continue page-by-page migration and backend transaction testing; do not delete legacy routes until their dependencies are checked.

## Required next audit steps

- [ ] Confirm GitHub Pages publishing source and live URL mapping for root files vs `public/`.
- [ ] Parse every product HTML file for local links, form actions, script and stylesheet references.
- [ ] Check each internal target exists and flag broken links / likely 404s.
- [ ] Identify canonical pages for each user journey and mark legacy aliases/redirects.
- [ ] Inspect repeated functions across root, `public/`, `app/`, `src/`, and `workspaces/`.
- [ ] Verify links from the homepage and each role entry into the correct workspace.
- [ ] Test high-risk workflows: authentication/RBAC, quote acceptance, payment verification, assignment, milestone persistence, delivery evidence, finance reconciliation.
- [ ] Only after dependencies and live routes are understood, prepare a separate safe-removal/redirect plan.
- [ ] Attach automated and browser test evidence before changing a status to verified.

## Status definitions

- **Inventoried:** File is present in the selected Git tree.
- **Route-mapped:** Live URL and publishing root are confirmed.
- **Link-checked:** Local references and targets were inspected.
- **Function-tested:** User action was exercised and expected persisted result confirmed.
- **Security-tested:** Role and tenant isolation were tested with appropriate non-privileged identities.
- **Verified:** Required tests passed and evidence is recorded.
- **Legacy candidate:** Possible overlap identified; not safe to delete until dependencies are checked.

**Safety rule:** Never delete a page solely because its filename or displayed title resembles another page. Preserve the approved canonical Customer Shipment Dashboard and other already-approved journeys; investigate bad duplicate interfaces and legacy routes before changing them.
