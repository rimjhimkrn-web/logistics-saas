# KRIM Logistics — Phase 13 Audit
## Customer Retention & Repeat Booking
**Audit date:** 2026-10-23  
**Repository:** `rimjhimkrn-web/logistics-saas`

## Scope
This phase follows the Global Customer Ecosystem Master Checklist. Preserve working journeys, reuse canonical customer workspace pages, avoid duplicate modules, and do not mark a capability verified merely because an HTML page exists.

## Existing pages inspected
- `public/customer/address-book.html`
- `public/customer/ratings-reviews.html`
- `public/customer/recurring-shipments.html`
- `public/customer/reorder.html`
- `public/customer/saved-routes.html`
- `public/customer/shipping-preferences.html`
- `public/customer/workspace.html`

## Source-level findings
1. `address-book.html` contains hard-coded sample facilities (Mumbai hub and JNPT gate), and the page describes facility/hub management rather than a customer's persisted address book. Its primary action routes to shipment creation, not the shipping-preferences page described by its label.
2. `ratings-reviews.html` contains hard-coded shipment references and carrier names. The form fields are not given stable names/IDs for backend submission, and its submit handler displays a success alert and navigates to Support without persisting a review.
3. `recurring-shipments.html` displays a hard-coded weekly dispatch and an "Active Cron" badge. The visible action routes to Returns; no saved schedule or recurring-booking persistence is demonstrated in this page.
4. `reorder.html` displays a hard-coded shipment and the Clone & Reorder button only shows an alert; no new booking draft is created.
5. `saved-routes.html` displays a hard-coded corridor and the Use Route button only shows an alert; no saved route is loaded into a real quote or shipment draft.
6. `shipping-preferences.html` shows preselected preferences, but its Save action displays a success alert and navigates away. Persistence is not demonstrated.
7. `workspace.html` links to multiple customer modules, including an alternate shipment-list path under `public/customer-os/customer-services/`; those routes and role checks need a separate route/authorization audit.
8. These pages use a mix of dark Tailwind utility styling and the shared KRIM stylesheet. Visual and mobile consistency still require browser verification.

## Phase 13 acceptance checklist
- [ ] 13.1 Request feedback only after an appropriate, authoritative milestone (e.g. delivery confirmed).
- [ ] 13.2 Save ratings/reviews against an authorized shipment and customer; prevent duplicate or abusive submissions.
- [ ] 13.3 Persist frequently used customer addresses with organization/user isolation.
- [ ] 13.4 Persist reusable shipment details/templates without exposing another customer's data.
- [ ] 13.5 Reorder from an authorized historical shipment by creating a new draft, revalidating route, cargo, price and service availability; never clone a booking as already confirmed.
- [ ] 13.6 Persist recurring-shipment schedules; generate new drafts/bookings only under explicit customer-configured rules and valid current rates/availability.
- [ ] 13.7 Provide authorized shipment history and actual downloadable records.
- [ ] 13.8 Identify recurring issues from verified support/exception records.
- [ ] 13.9 Make feedback available to authorized quality workflows.
- [ ] 13.10 Define retention and repeat-booking metrics from real persisted records, not hard-coded counts.

## Implementation order
1. Audit Supabase tables, RLS policies, RPCs and existing customer identity/organization relations before adding schema.
2. Establish the canonical saved-address workflow and remove sample facility rows from the customer-facing address book.
3. Connect reorder to an authorized shipment record and create a fresh draft using current validation and quote flow.
4. Replace recurring-shipment sample data with a clearly scoped schedule workflow; do not claim a cron job is active unless backed by configuration and execution evidence.
5. Connect ratings/reviews to completed shipments and persist them securely.
6. Verify records, permissions, duplicate submission handling, navigation and mobile rendering.
7. Mark each checklist item verified only after evidence from real test accounts and backend records.

## Current status
**Phase 13: IN PROGRESS — audit findings recorded.** This commit documents source-level findings and acceptance criteria. It does not implement the persistence layer and does not establish successful deployment or end-to-end acceptance.
