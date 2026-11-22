# KRIM Global Logistics OS — Master Lifecycle File Checklist

**Purpose:** One controlled inventory for the complete customer, partner, enterprise, carrier, warehouse, finance, compliance, operations and platform lifecycle.
**Repository:** `rimjhimkrn-web/logistics-saas`
**Baseline branch:** `main`
**Working branch:** `krim/global-lifecycle-blueprint`
**Status rule:** A file existing is not proof that it works. Mark a page **functional** only after its UI, route, authorization, backend contract, empty/error/loading states and end-to-end test pass. Do not put secrets in frontend files.

## Status key
- [ ] Not verified / not built
- [x] Verified by direct test (record evidence in the implementation tracker)
- [~] File exists but functionality/backend wiring is not yet verified
- [!] Security, correctness, routing or operational blocker

## 0. Architecture, shared UI and application shell
- [ ] `core/krim-core.css` — design tokens, typography, responsive layout
- [ ] `core/krim-components.css` — buttons, forms, cards, tables, dialogs, toasts
- [ ] `core/krim-accessibility.css` — focus, keyboard, contrast, reduced motion
- [ ] `platform/krim-config.js` — public configuration only; no secrets
- [ ] `platform/krim-supabase.js` — one Supabase client and session handling
- [ ] `platform/krim-api.js` — typed/validated API and Edge Function wrapper
- [ ] `platform/krim-auth-guard.js` — signed-in route guard
- [ ] `platform/krim-role-guard.js` — role/org route guard (never a substitute for RLS)
- [ ] `platform/krim-navigation.js` — shared responsive navigation and safe return routes
- [ ] `platform/krim-route-map.js` — canonical routes and redirects
- [ ] `platform/krim-form-validation.js` — shared client validation (server validates again)
- [ ] `platform/krim-formatters.js` — currency, units, dates, addresses, phone
- [ ] `platform/krim-i18n.js` — language and locale selection
- [ ] `platform/krim-telemetry.js` — privacy-safe error/performance telemetry
- [ ] `platform/krim-feature-flags.js` — staged rollout by market/role
- [ ] `platform/krim-offline-queue.js` — optional safe field-app retry queue
- [ ] `platform/krim-notifications.js` — in-app notification client
- [ ] `platform/krim-upload.js` — signed/private file upload helper
- [ ] `platform/krim-realtime.js` — authorized realtime subscriptions
- [ ] `platform/krim-idempotency.js` — request keys for retry-safe actions
- [ ] `platform/krim-error-boundary.js` — user-safe failure UI
- [ ] `platform/krim-consent.js` — consent and preference handling
- [ ] `platform/krim-accessibility.js` — reusable accessibility helpers

## 1. Public website and discovery
- [ ] `public/index.html` — home / Get Started entry point
- [ ] `public/platform.html` — platform overview
- [ ] `public/solutions.html` — solutions by shipment/user segment
- [ ] `public/global-coverage.html` — supported markets and limitations (never claim live coverage without evidence)
- [ ] `public/transport-modes.html` — road, rail, ocean, air, multimodal
- [ ] `public/industries.html` — industries served
- [ ] `public/how-it-works.html` — lifecycle explainer
- [ ] `public/pricing.html` — published pricing/fees and assumptions
- [ ] `public/quote.html` — quote request entry
- [ ] `public/quote-result.html` — backend-backed quote result and checkout, not a hardcoded price
- [ ] `public/tracking.html` — public tracking only with scoped, non-sensitive tracking token
- [ ] `public/partners.html` — partner network
- [ ] `public/become-a-partner.html` — partner acquisition entry
- [ ] `public/enterprise.html` — enterprise contact / onboarding
- [ ] `public/integrations.html` — integrations catalogue
- [ ] `public/security.html` — security and responsible disclosure
- [ ] `public/trust.html` — service standards and operational transparency
- [ ] `public/status.html` — public service status only if status data is actually operated
- [ ] `public/about.html` — company
- [ ] `public/contact.html` — support and sales contact
- [ ] `public/help.html` — public help centre
- [ ] `public/faq.html` — frequently asked questions
- [ ] `public/careers.html` — careers (only if maintained)
- [ ] `public/press.html` — media assets (only if maintained)
- [ ] `public/robots.txt` — crawler policy
- [ ] `public/sitemap.xml` — published routes
- [ ] `public/404.html` — branded not-found page
- [ ] `public/maintenance.html` — controlled maintenance page
- [ ] `public/growth/partner-acquisition.html` — partner campaign landing page
- [ ] `public/growth/customer-acquisition.html` — customer campaign landing page
- [ ] `public/growth/campaign-landing.html` — approved campaign template
- [ ] `public/growth/referral.html` — referral landing / attribution
- [ ] `public/growth/acquisition-command.html` — privileged/internal only; not public navigation
- [ ] `public/growth/prospect-registry.html` — privileged/internal only; protect prospect data

## 2. Identity, registration and account lifecycle
- [ ] `auth/login.html`
- [ ] `auth/register.html` — user registration / account type choice
- [ ] `auth/customer-signup.html`
- [ ] `auth/partner-signup.html`
- [ ] `auth/enterprise-signup.html`
- [ ] `auth/driver-signup.html` — invitation/partner-controlled where appropriate
- [ ] `auth/warehouse-signup.html`
- [ ] `auth/forwarder-signup.html`
- [ ] `auth/verify-email.html`
- [ ] `auth/verify-phone.html` — only with a configured provider
- [ ] `auth/auth-callback.html`
- [ ] `auth/invitation.html`
- [ ] `auth/organization-invitation-acceptance.html`
- [ ] `auth/forgot-password.html`
- [ ] `auth/reset-password.html`
- [ ] `auth/change-password.html`
- [ ] `auth/change-email.html`
- [ ] `auth/change-phone.html`
- [ ] `auth/mfa-enroll.html`
- [ ] `auth/mfa-challenge.html`
- [ ] `auth/passkey-management.html`
- [ ] `auth/backup-codes.html`
- [ ] `auth/active-sessions.html`
- [ ] `auth/device-management.html`
- [ ] `auth/organization-switch.html`
- [ ] `auth/identity-verification.html`
- [ ] `auth/consent-management.html`
- [ ] `auth/account-recovery-status.html`
- [ ] `auth/recovery.html`
- [ ] `auth/account-deactivation.html`
- [ ] `auth/account-deletion.html`
- [ ] `auth/logout.html`
- [ ] `auth/disabled.html` — safe account-disabled explanation
- [ ] `auth/terms-acceptance.html` — versioned terms acceptance

## 3. First login, setup and organization administration
- [ ] `onboarding/index.html` — role-aware onboarding router
- [ ] `onboarding/profile.html`
- [ ] `onboarding/organization-create.html`
- [ ] `onboarding/organization-details.html`
- [ ] `onboarding/organization-verification.html`
- [ ] `onboarding/business-documents.html`
- [ ] `onboarding/tax-and-registration.html` — market-specific fields
- [ ] `onboarding/billing-profile.html`
- [ ] `onboarding/service-preferences.html`
- [ ] `onboarding/notification-preferences.html`
- [ ] `onboarding/complete.html`
- [ ] `settings/profile.html`
- [ ] `settings/organization.html`
- [ ] `settings/members.html`
- [ ] `settings/roles-permissions.html`
- [ ] `settings/invitations.html`
- [ ] `settings/api-keys.html` — secrets shown once only; server-side management
- [ ] `settings/webhooks.html`
- [ ] `settings/integrations.html`
- [ ] `settings/locations.html`
- [ ] `settings/branches.html`
- [ ] `settings/operating-hours.html`
- [ ] `settings/branding.html`
- [ ] `settings/billing.html`
- [ ] `settings/security.html`
- [ ] `settings/audit-log.html`
- [ ] `settings/data-export.html`
- [ ] `settings/data-retention.html`
- [ ] `settings/connected-apps.html`

## 4. Customer / shipper lifecycle
- [ ] `app/customer/index.html` — customer dashboard
- [ ] `app/customer/get-started.html`
- [ ] `app/customer/create-shipment.html`
- [ ] `app/customer/shipment-draft.html`
- [ ] `app/customer/shipments.html`
- [ ] `app/customer/shipment-details.html`
- [ ] `app/customer/route-and-stops.html`
- [ ] `app/customer/cargo-details.html`
- [ ] `app/customer/commodity-and-handling.html`
- [ ] `app/customer/documents.html`
- [ ] `app/customer/request-quote.html`
- [ ] `app/customer/quotes.html`
- [ ] `app/customer/quote-comparison.html`
- [ ] `app/customer/quote-details.html`
- [ ] `app/customer/booking-confirmation.html`
- [ ] `app/customer/booking-amendment.html`
- [ ] `app/customer/tracking.html`
- [ ] `app/customer/milestones.html`
- [ ] `app/customer/proof-of-delivery.html`
- [ ] `app/customer/claims.html`
- [ ] `app/customer/cancellations.html`
- [ ] `app/customer/returns-and-reverse-logistics.html`
- [ ] `app/customer/invoices.html`
- [ ] `app/customer/invoice-details.html`
- [ ] `app/customer/payments.html`
- [ ] `app/customer/payment-receipt.html`
- [ ] `app/customer/credit-and-wallet.html` — only if legally/financially supported
- [ ] `app/customer/recurring-shipments.html`
- [ ] `app/customer/saved-routes.html`
- [ ] `app/customer/address-book.html`
- [ ] `app/customer/contacts.html`
- [ ] `app/customer/notifications.html`
- [ ] `app/customer/support.html`
- [ ] `app/customer/disputes.html`
- [ ] `app/customer/feedback.html`
- [ ] `app/customer/reports.html`
- [ ] `app/customer/sub-users.html`
- [ ] `app/customer/preferences.html`

## 5. Carrier / truck owner / driver lifecycle
- [ ] `app/partner/index.html` — partner dashboard
- [ ] `app/partner/application-status.html`
- [ ] `app/partner/verification.html`
- [ ] `app/partner/business-profile.html`
- [ ] `app/partner/operating-regions.html`
- [ ] `app/partner/fleet.html`
- [ ] `app/partner/vehicles.html`
- [ ] `app/partner/vehicle-details.html`
- [ ] `app/partner/drivers.html`
- [ ] `app/partner/driver-invitations.html`
- [ ] `app/partner/documents-and-expiry.html`
- [ ] `app/partner/insurance-and-permits.html`
- [ ] `app/partner/capacity-calendar.html`
- [ ] `app/partner/available-loads.html`
- [ ] `app/partner/load-details.html`
- [ ] `app/partner/submit-quote.html`
- [ ] `app/partner/my-quotes.html`
- [ ] `app/partner/awarded-loads.html`
- [ ] `app/partner/assign-vehicle-driver.html`
- [ ] `app/partner/dispatch.html`
- [ ] `app/partner/trip-management.html`
- [ ] `app/partner/location-updates.html`
- [ ] `app/partner/milestone-updates.html`
- [ ] `app/partner/pickup-confirmation.html`
- [ ] `app/partner/delivery-confirmation.html`
- [ ] `app/partner/proof-of-delivery-upload.html`
- [ ] `app/partner/exception-reporting.html`
- [ ] `app/partner/claims-and-damage.html`
- [ ] `app/partner/settlements.html`
- [ ] `app/partner/settlement-details.html`
- [ ] `app/partner/payout-account.html`
- [ ] `app/partner/performance.html`
- [ ] `app/partner/ratings-and-feedback.html`
- [ ] `app/partner/compliance-status.html`
- [ ] `app/partner/support.html`
- [ ] `app/partner/referrals.html`
- [ ] `app/partner/subcontractors.html` — permission-controlled and legally reviewed

## 6. Driver / field operations
- [ ] `app/driver/index.html`
- [ ] `app/driver/today.html`
- [ ] `app/driver/assigned-trip.html`
- [ ] `app/driver/navigation-and-stops.html`
- [ ] `app/driver/pickup-checklist.html`
- [ ] `app/driver/cargo-condition.html`
- [ ] `app/driver/waybill-and-documents.html`
- [ ] `app/driver/location-sharing.html`
- [ ] `app/driver/status-update.html`
- [ ] `app/driver/delay-and-incident.html`
- [ ] `app/driver/delivery-checklist.html`
- [ ] `app/driver/recipient-signature.html`
- [ ] `app/driver/photo-proof.html`
- [ ] `app/driver/expenses-and-advances.html`
- [ ] `app/driver/safety-check.html`
- [ ] `app/driver/offline-sync.html`
- [ ] `app/driver/help-and-emergency.html`
- [ ] `app/driver/shift-and-availability.html`

## 7. Freight forwarder, broker and network partner
- [ ] `app/forwarder/index.html`
- [ ] `app/forwarder/shipments.html`
- [ ] `app/forwarder/rate-management.html`
- [ ] `app/forwarder/carrier-directory.html`
- [ ] `app/forwarder/buy-rates.html`
- [ ] `app/forwarder/sell-rates.html`
- [ ] `app/forwarder/consolidation.html`
- [ ] `app/forwarder/house-master-documents.html`
- [ ] `app/forwarder/agent-network.html`
- [ ] `app/forwarder/booking-management.html`
- [ ] `app/forwarder/track-and-trace.html`
- [ ] `app/forwarder/commission-and-margin.html`
- [ ] `app/forwarder/reconciliation.html`
- [ ] `app/forwarder/claims.html`
- [ ] `app/forwarder/performance.html`

## 8. Warehouse, fulfilment and inventory operators
- [ ] `app/warehouse/index.html`
- [ ] `app/warehouse/facility-profile.html`
- [ ] `app/warehouse/capacity-and-slots.html`
- [ ] `app/warehouse/appointments.html`
- [ ] `app/warehouse/inbound-planning.html`
- [ ] `app/warehouse/receiving.html`
- [ ] `app/warehouse/quality-and-damage.html`
- [ ] `app/warehouse/inventory.html`
- [ ] `app/warehouse/bin-and-location.html`
- [ ] `app/warehouse/picking.html`
- [ ] `app/warehouse/packing.html`
- [ ] `app/warehouse/cross-dock.html`
- [ ] `app/warehouse/outbound-planning.html`
- [ ] `app/warehouse/loading.html`
- [ ] `app/warehouse/dispatch-confirmation.html`
- [ ] `app/warehouse/returns.html`
- [ ] `app/warehouse/labour-and-shifts.html`
- [ ] `app/warehouse/equipment-and-maintenance.html`
- [ ] `app/warehouse/billing.html`
- [ ] `app/warehouse/stock-reconciliation.html`
- [ ] `app/warehouse/reports.html`

## 9. Customs, trade and cross-border operations
- [ ] `app/customs/index.html`
- [ ] `app/customs/shipment-clearance.html`
- [ ] `app/customs/party-and-tax-identifiers.html`
- [ ] `app/customs/commodity-classification.html`
- [ ] `app/customs/commercial-invoice.html`
- [ ] `app/customs/packing-list.html`
- [ ] `app/customs/certificate-of-origin.html`
- [ ] `app/customs/permits-and-licenses.html`
- [ ] `app/customs/export-declaration.html`
- [ ] `app/customs/import-declaration.html`
- [ ] `app/customs/sanctions-screening.html`
- [ ] `app/customs/dual-use-review.html`
- [ ] `app/customs/broker-assignment.html`
- [ ] `app/customs/inspection-and-holds.html`
- [ ] `app/customs/duties-and-taxes.html`
- [ ] `app/customs/clearance-milestones.html`
- [ ] `app/customs/document-expiry.html`
- [ ] `app/customs/audit-trail.html`
- [ ] `app/customs/regulatory-alerts.html`

## 10. Enterprise shipper / supply-chain control tower
- [ ] `app/enterprise/index.html`
- [ ] `app/enterprise/control-tower.html`
- [ ] `app/enterprise/multi-entity.html`
- [ ] `app/enterprise/procurement.html`
- [ ] `app/enterprise/rate-cards.html`
- [ ] `app/enterprise/tender-management.html`
- [ ] `app/enterprise/contract-management.html`
- [ ] `app/enterprise/shipment-planning.html`
- [ ] `app/enterprise/multi-leg-routing.html`
- [ ] `app/enterprise/carbon-and-sustainability.html`
- [ ] `app/enterprise/visibility-and-exceptions.html`
- [ ] `app/enterprise/sla-management.html`
- [ ] `app/enterprise/budget-and-cost-centres.html`
- [ ] `app/enterprise/approval-workflows.html`
- [ ] `app/enterprise/edi-and-api.html`
- [ ] `app/enterprise/erp-integration.html`
- [ ] `app/enterprise/analytics.html`
- [ ] `app/enterprise/forecasting.html`
- [ ] `app/enterprise/reconciliation.html`
- [ ] `app/enterprise/chargeback.html`
- [ ] `app/enterprise/multi-country-tax.html`
- [ ] `app/enterprise/service-review.html`

## 11. Finance, payments, billing and settlement
- [ ] `app/finance/index.html`
- [ ] `app/finance/receivables.html`
- [ ] `app/finance/payables.html`
- [ ] `app/finance/invoices.html`
- [ ] `app/finance/credit-notes.html`
- [ ] `app/finance/payment-attempts.html`
- [ ] `app/finance/payment-details.html`
- [ ] `app/finance/payment-reconciliation.html`
- [ ] `app/finance/revenue-ledger.html`
- [ ] `app/finance/commission-rules.html`
- [ ] `app/finance/partner-settlements.html`
- [ ] `app/finance/payout-batches.html`
- [ ] `app/finance/refunds.html`
- [ ] `app/finance/disputes-and-chargebacks.html`
- [ ] `app/finance/tax-reports.html`
- [ ] `app/finance/fx-rates.html`
- [ ] `app/finance/multi-currency-ledger.html`
- [ ] `app/finance/bank-reconciliation.html`
- [ ] `app/finance/financial-close.html`
- [ ] `app/finance/financial-reports.html`
- [ ] `app/finance/payout-account-verification.html`
- [ ] `app/finance/payment-provider-health.html`
- [ ] `app/finance/financial-controls.html`
- [ ] `app/finance/settlement-exceptions.html`

## 12. Customer support, claims and service quality
- [ ] `app/support/index.html`
- [ ] `app/support/tickets.html`
- [ ] `app/support/ticket-details.html`
- [ ] `app/support/conversations.html`
- [ ] `app/support/knowledge-base.html`
- [ ] `app/support/claims.html`
- [ ] `app/support/claim-review.html`
- [ ] `app/support/disputes.html`
- [ ] `app/support/refunds.html`
- [ ] `app/support/escalations.html`
- [ ] `app/support/sla-breaches.html`
- [ ] `app/support/customer-feedback.html`
- [ ] `app/support/root-cause.html`
- [ ] `app/support/compensation-policy.html`

## 13. Internal operations and privileged Global Control Centre
> Must remain isolated from public navigation. All privileged actions require server-side authorization, audit trails and least privilege. UI visibility alone is not security.
- [ ] `control/index.html` — privileged control centre entry
- [ ] `control/system-health.html`
- [ ] `control/organizations.html`
- [ ] `control/users-and-access.html`
- [ ] `control/rbac.html`
- [ ] `control/audit-events.html`
- [ ] `control/security-incidents.html`
- [ ] `control/sessions-and-risk.html`
- [ ] `control/market-configuration.html`
- [ ] `control/countries-and-currencies.html`
- [ ] `control/service-catalogue.html`
- [ ] `control/partner-verification-queue.html`
- [ ] `control/customer-risk-queue.html`
- [ ] `control/shipment-operations.html`
- [ ] `control/assignment-operations.html`
- [ ] `control/exception-command.html`
- [ ] `control/claims-command.html`
- [ ] `control/payment-operations.html`
- [ ] `control/settlement-operations.html`
- [ ] `control/refund-approvals.html`
- [ ] `control/commission-configuration.html`
- [ ] `control/integrations-and-webhooks.html`
- [ ] `control/job-scheduler.html`
- [ ] `control/automation-runs.html`
- [ ] `control/dead-letter-queue.html`
- [ ] `control/data-quality.html`
- [ ] `control/feature-flags.html`
- [ ] `control/incident-management.html`
- [ ] `control/backup-and-restore.html`
- [ ] `control/retention-and-privacy.html`
- [ ] `control/compliance-monitoring.html`
- [ ] `control/vendor-management.html`
- [ ] `control/cost-and-usage.html`
- [ ] `control/change-management.html`
- [ ] `control/maintenance-mode.html`

## 14. AI, optimisation and decision support
- [ ] `app/intelligence/index.html`
- [ ] `app/intelligence/route-recommendations.html`
- [ ] `app/intelligence/rate-benchmarking.html`
- [ ] `app/intelligence/load-matching.html`
- [ ] `app/intelligence/demand-forecast.html`
- [ ] `app/intelligence/eta-prediction.html`
- [ ] `app/intelligence/exception-prediction.html`
- [ ] `app/intelligence/capacity-planning.html`
- [ ] `app/intelligence/consolidation.html`
- [ ] `app/intelligence/carbon-estimation.html`
- [ ] `app/intelligence/document-extraction.html`
- [ ] `app/intelligence/support-assistant.html`
- [ ] `app/intelligence/decision-explanations.html`
- [ ] `app/intelligence/model-quality.html`
- [ ] `app/intelligence/human-review-queue.html`
- [ ] `app/intelligence/ai-usage-and-cost.html`
- [ ] `app/intelligence/prompt-and-policy-controls.html`
- [ ] `app/intelligence/evaluation-dashboard.html`

## 15. Integrations and developer platform
- [ ] `developers/index.html`
- [ ] `developers/getting-started.html`
- [ ] `developers/authentication.html`
- [ ] `developers/api-reference.html`
- [ ] `developers/webhooks.html`
- [ ] `developers/events.html`
- [ ] `developers/errors-and-retries.html`
- [ ] `developers/idempotency.html`
- [ ] `developers/rate-limits.html`
- [ ] `developers/sandbox.html`
- [ ] `developers/changelog.html`
- [ ] `developers/status.html`
- [ ] `integrations/erp.html`
- [ ] `integrations/wms.html`
- [ ] `integrations/tms.html`
- [ ] `integrations/edi.html`
- [ ] `integrations/telematics.html`
- [ ] `integrations/maps-and-geocoding.html`
- [ ] `integrations/notifications.html`
- [ ] `integrations/payment-providers.html`
- [ ] `integrations/customs-and-trade.html`
- [ ] `integrations/marketplaces.html`
- [ ] `integrations/connection-health.html`
- [ ] `integrations/sync-runs.html`
- [ ] `integrations/mapping-and-transforms.html`

## 16. Global compliance, risk, privacy and sustainability
- [ ] `legal/terms.html`
- [ ] `legal/privacy.html`
- [ ] `legal/cookies.html`
- [ ] `legal/data-processing.html`
- [ ] `legal/acceptable-use.html`
- [ ] `legal/partner-agreement.html`
- [ ] `legal/service-levels.html`
- [ ] `legal/payment-and-refund-policy.html`
- [ ] `legal/claims-policy.html`
- [ ] `legal/retention-policy.html`
- [ ] `legal/subprocessors.html`
- [ ] `legal/security-disclosure.html`
- [ ] `legal/accessibility.html`
- [ ] `legal/market-specific-terms.html`
- [ ] `app/compliance/index.html`
- [ ] `app/compliance/kyb-kyc.html`
- [ ] `app/compliance/sanctions-and-watchlists.html`
- [ ] `app/compliance/export-controls.html`
- [ ] `app/compliance/dual-use-goods.html`
- [ ] `app/compliance/dangerous-goods.html`
- [ ] `app/compliance/privacy-requests.html`
- [ ] `app/compliance/data-residency.html`
- [ ] `app/compliance/retention-and-deletion.html`
- [ ] `app/compliance/consent-records.html`
- [ ] `app/compliance/regulatory-change-log.html`
- [ ] `app/compliance/sustainability-reporting.html`
- [ ] `app/compliance/incident-reporting.html`

## 17. Cross-cutting pages used by all roles
- [ ] `app/notifications.html`
- [ ] `app/tasks.html`
- [ ] `app/calendar.html`
- [ ] `app/search.html`
- [ ] `app/files.html`
- [ ] `app/activity.html`
- [ ] `app/help.html`
- [ ] `app/feedback.html`
- [ ] `app/preferences.html`
- [ ] `app/announcements.html`
- [ ] `app/maintenance.html`
- [ ] `app/forbidden.html`
- [ ] `app/not-found.html`

## 18. Backend assets that pages depend on (not browser pages)
- [ ] `supabase/migrations/` — versioned schema changes; no manual-only production drift
- [ ] `supabase/seed/` — safe non-production reference data
- [ ] `supabase/functions/create-razorpay-order/` — authoritative order creation from server-verified quote/booking
- [ ] `supabase/functions/verify-razorpay-payment/` — signature/status verification and idempotent ledger write
- [ ] `supabase/functions/razorpay-webhook/` — signature-verified, replay-safe provider webhook
- [ ] `supabase/functions/krim-notification-provider-adapter/`
- [ ] `supabase/functions/krim-ai/` — guarded AI operations, quotas and audit
- [ ] `supabase/functions/global-admin-control/` — privileged server boundary
- [ ] `supabase/functions/partner-application/`
- [ ] `supabase/functions/partner-verification/`
- [ ] `supabase/functions/quote-engine/`
- [ ] `supabase/functions/shipment-lifecycle/`
- [ ] `supabase/functions/partner-matching/`
- [ ] `supabase/functions/tracking-ingest/`
- [ ] `supabase/functions/document-upload/`
- [ ] `supabase/functions/notification-dispatch/`
- [ ] `supabase/functions/settlement-runner/`
- [ ] `supabase/functions/refund-orchestrator/`
- [ ] `supabase/functions/webhook-dispatcher/`
- [ ] `supabase/functions/integration-sync/`
- [ ] `supabase/functions/compliance-screening/`
- [ ] `supabase/functions/privacy-request-handler/`
- [ ] `supabase/functions/automation-runner/`
- [ ] `supabase/functions/health-check/`
- [ ] `supabase/functions/dead-letter-replay/` — privileged, approval/audit protected

**Important:** These are required capabilities/file-path targets, not a claim that these exact functions already exist. Inspect the live function inventory and existing SQL before creating or duplicating them. Reuse working existing contracts where possible.

## 19. Database capability checklist (schema is not a page)
- [ ] Global markets, countries, regions, currencies, units, time zones, languages
- [ ] Organizations, branches, members, invitations, role assignments, permissions
- [ ] Customer profiles, partner profiles, carrier/fleet/driver, warehouse, forwarder, broker profiles
- [ ] Verification cases, evidence, review decisions, expiry and re-verification
- [ ] Shipments, cargo, parties, addresses, stops, legs, route plans, milestones, tracking events
- [ ] Quote requests, quote versions, rate cards, tariffs, accessorials, tax, quote acceptance
- [ ] Booking confirmation, assignment, capacity reservation, cancellation and amendment
- [ ] Documents, private storage metadata, malware scan status, access logs, retention
- [ ] Warehouse facilities, slots, inventory, handling events, fulfilment
- [ ] Cross-border declarations, classification, permits, compliance decisions and holds
- [ ] Invoices, payment attempts, provider events, refunds, disputes, revenue ledger
- [ ] Commission policy versions, partner payable ledger, settlement batches, payout status
- [ ] Claims, damages, disputes, service tickets, SLA clocks, feedback
- [ ] Notifications, templates, preferences, delivery attempts, suppression
- [ ] Integrations, credentials references, webhook subscriptions/deliveries, sync cursors
- [ ] Automation definitions, execution logs, retry schedule, dead-letter events
- [ ] Audit events, security events, access decisions, consent, privacy requests
- [ ] Idempotency keys, outbox/inbox, deduplication and transactional event records
- [ ] Reporting aggregates with tenant isolation and safe row-level access
- [ ] RLS policies for every tenant-owned table; explicit tests for cross-organization denial
- [ ] Indexes, constraints, foreign keys, immutable financial/audit records where appropriate
- [ ] Backup, restore, retention and deletion procedures tested

## 20. Automated quality, security and release gates
- [ ] `tests/routes/route-smoke.test.js` — every navigation link resolves
- [ ] `tests/routes/get-started-flow.test.js` — CTA → registration → verification → onboarding
- [ ] `tests/auth/role-routing.test.js` — every role lands in correct workspace
- [ ] `tests/auth/unauthorized-access.test.js`
- [ ] `tests/security/tenant-isolation.test.js`
- [ ] `tests/security/rls-policy.test.sql`
- [ ] `tests/security/secret-scan.test.js`
- [ ] `tests/security/public-tracking.test.js`
- [ ] `tests/shipments/create-to-delivery.test.js`
- [ ] `tests/quotes/quote-to-acceptance.test.js`
- [ ] `tests/payments/order-signature-ledger.test.js`
- [ ] `tests/payments/webhook-idempotency.test.js`
- [ ] `tests/payments/false-success-prevention.test.js`
- [ ] `tests/partners/application-to-first-load.test.js`
- [ ] `tests/partners/settlement-reconciliation.test.js`
- [ ] `tests/automation/retry-dead-letter.test.js`
- [ ] `tests/accessibility/keyboard-and-labels.test.js`
- [ ] `tests/mobile/responsive-smoke.test.js`
- [ ] `tests/i18n/locale-currency-timezone.test.js`
- [ ] `tests/integrations/webhook-signature-replay.test.js`
- [ ] `tests/fixtures/README.md` — synthetic data only
- [ ] `.github/workflows/validate.yml` — static checks and tests
- [ ] `.github/workflows/security.yml` — dependency/secret checks
- [ ] `.github/workflows/deploy-preview.yml` — preview deployment
- [ ] `docs/RELEASE-GATES.md` — staging/live go/no-go criteria

## 21. Operations and founder evidence
- [ ] `docs/ARCHITECTURE.md`
- [ ] `docs/ROUTE-AND-LIFECYCLE-MAP.md`
- [ ] `docs/BACKEND-CONTRACTS.md`
- [ ] `docs/DATA-DICTIONARY.md`
- [ ] `docs/THREAT-MODEL.md`
- [ ] `docs/INCIDENT-RESPONSE.md`
- [ ] `docs/BACKUP-RESTORE-RUNBOOK.md`
- [ ] `docs/ON-CALL-AND-ESCALATION.md`
- [ ] `docs/MARKET-LAUNCH-CHECKLIST.md`
- [ ] `docs/PARTNER-ONBOARDING-RUNBOOK.md`
- [ ] `docs/CUSTOMER-SUPPORT-RUNBOOK.md`
- [ ] `docs/FINANCE-RECONCILIATION-RUNBOOK.md`
- [ ] `docs/COMPLIANCE-COUNTRY-MATRIX.md`
- [ ] `docs/THIRD-PARTY-DEPENDENCIES.md`
- [ ] `docs/KNOWN-LIMITATIONS.md`
- [ ] `docs/DECISIONS/` — dated architecture decisions
- [ ] `docs/FOUNDER-EVIDENCE-LOG.md` — dated, verifiable milestones, tests, setbacks and outcomes

## Lifecycle acceptance gates (must pass before live launch)
1. **Navigation:** every CTA opens a real, appropriate next page; no dead links or fake-success alerts.
2. **Identity:** sign-up, email verification, login, reset, logout and session expiry work end-to-end.
3. **Authorization:** server-side role checks plus RLS; cross-tenant access is denied by automated tests.
4. **Partner first:** application → verification → contract/terms → capacity → quote/load → assignment → proof of delivery → reconciliation → settlement.
5. **Customer:** request → server-calculated quote → acceptance → booking → tracking → delivery → invoice/payment → support/claims.
6. **Payments:** backend-calculated amount; order bound to authenticated user/booking; signature and provider status verified; idempotent ledger entries; webhook replay-safe; no success message until backend confirms.
7. **Operations:** exceptions, retries, dead-letter handling, alerting, audit and recovery are exercised.
8. **Global readiness:** locale/currency/time zone/units and market-specific legal/compliance rules are data-driven; do not promise every country is operational until local providers, regulations, service coverage and tests are validated.
9. **Production readiness:** staging end-to-end tests, secrets stored server-side, backups/restore tested, monitoring/incident runbooks ready, live payment keys switched only after formal go/no-go review.
10. **Growth automation:** use consent-respecting, legally reviewed outreach with suppression/opt-out, verified target lists, rate limits and human approval before sending campaigns. Do not activate mass outreach before partner operations and customer support can fulfil demand.

## Implementation tracker
For each item, record: **status, existing path (if any), owner, backend contract, test evidence, blocker, last verified date**. A checklist entry is not proof of completion. Keep `main` unchanged until the staged branch has been reviewed and its tests pass.
