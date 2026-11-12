# KRIM Customer Journey — Step 2: Booking Idempotency & Recovery Audit

**Audit date:** 2026-11-13  
**Branch:** `website/global-launch-readiness`  
**Scope:** Canonical customer booking form, retry identifier lifecycle, existing shipment idempotency contract, and quote hand-off.  
**Disposition:** **Core duplicate prevention is present; uncertain-outcome recovery remains incomplete.**

## What was inspected

- `public/shipper/booking-request.html` — canonical customer shipment request.
- `public/customer/shipment-create.html` — legacy redirect to the canonical form.
- `public/shipper/quote-comparison.html` — downstream quote comparison and acceptance.
- `docs/phase-3-shipment-creation-audit-2026-10-23.md` and `docs/audits/step-01-database-booking-integrity-2026-10-25.md` — previous recorded database invariant review.

## Safeguards present in the current page

1. The page generates a cryptographically random UUID and stores it in session storage under `krim_global_booking_request_id`.
2. It calls `krim_create_global_shipment_idempotent` with the authenticated customer's organization, origin/destination, cargo, weight, transport mode, route type and booking UUID.
3. The submit handler disables the button while the request is in flight.
4. A response without a usable shipment identifier does not show success and leaves the page locked to discourage blind resubmission.
5. A normal caught RPC error preserves the UUID, unlocks the button and explicitly tells the customer to check My Shipments if the network timed out.
6. On a successful response, the UUID is cleared and the customer is sent to the tariff/quote workflow using the returned shipment ID.
7. The earlier database audit records server-side authentication, organization access, `shipment.create` permission, active organization checks, advisory locking, same-request/same-details retry handling, changed-details rejection, RLS and a unique partial index on organization + booking request ID. This audit did not re-run production SQL or create a shipment.

## Findings requiring correction before declaring recovery production-ready

### F1 — No explicit recovery lookup after an uncertain result (HIGH)

When the browser loses the RPC response after the database commits, the page tells the customer to check My Shipments, but it does not provide a dedicated “recover this request” action that resolves the original booking UUID to the existing shipment. A customer who cannot identify the shipment in the list may be left uncertain whether to retry.

**Required:** provide a server-authorized recovery operation that accepts the booking UUID and returns only the shipment belonging to the authenticated user’s currently authorized organization. It must not create a shipment. If no matching record exists, it should explicitly report “not found” and allow retry with the same request UUID and unchanged payload.

### F2 — Booking payload is not persisted client-side for safe retry (HIGH)

The retry UUID survives a caught error in session storage, but the form values are not saved as a matching immutable request snapshot. If the customer reloads the page after an uncertain outcome, the UUID may remain while the form fields reset. Reusing that UUID with a different payload should be rejected by the server's idempotency guard, which is safe against duplicates but leaves the customer without a clear recovery path.

**Required:** persist a minimal, non-sensitive request snapshot alongside the UUID for the active tab/session, restore it after reload, and lock the payload while the outcome is uncertain. Do not store identity documents, credentials or unnecessary personal data in browser storage.

### F3 — UUID lifecycle needs explicit “new request” boundaries (MEDIUM)

The form uses one session-storage key for the active booking request and clears it only after a confirmed response. This is conservative for retry safety, but the interface does not expose an explicit recovery/new-request state. A user should never be encouraged to generate a new UUID merely because a response timed out.

**Required:** distinguish these states: editing/not submitted; submitting; confirmed with shipment ID; outcome uncertain/recovery required; confirmed not created/retry allowed. Generate a new UUID only after a confirmed success or an explicit server-confirmed no-record outcome that authorizes a fresh request.

### F4 — Market preflight is not proof of partner serviceability (MEDIUM)

The browser checks active country, location and market mappings before shipment creation. Those catalogue mappings must not be represented as verified partner capacity, a service promise or a price. The current copy says manual route review where the mapping is absent; downstream capability matching and quote validation must remain authoritative.

## Quote acceptance hand-off observations

- The comparison page scopes the shipment to active customer organization membership and loads quotes scoped to that shipment and customer organization.
- It requires a sent, unexpired, positive-value quote linked to a partner offer, a matching accepted partner assignment, and shipment status `quoted` before enabling acceptance.
- The server-side `krim_accept_global_quote` migration enforces customer-organization binding, access and permission, quote expiry/status, shipment state, linked partner offer, amount/currency equality, and an accepted assignment.
- A later migration proposal revalidates the partner organization's active/registered/verified/compliant state and shipment capability at the acceptance moment. That proposal is code-only and has not been applied or tested in staging.
- The browser optimistically updates the local quote/shipment display after the RPC returns the accepted quote. A follow-up authoritative read should replace the local status before the UI presents the final state as confirmed.

## Required tests before closing this step

- [ ] Two simultaneous submits with the same UUID and identical payload return one shipment.
- [ ] Retry after a simulated lost response returns the existing shipment ID, not a duplicate.
- [ ] Same UUID with changed payload is rejected without creating another shipment.
- [ ] Reload after an uncertain outcome restores the original request snapshot and supports safe recovery.
- [ ] Recovery UUID from another organization/user reveals no shipment and no sensitive existence information.
- [ ] No-record recovery permits retry with the same UUID; confirmed existing record navigates to its shipment.
- [ ] New request after a confirmed shipment receives a new UUID.
- [ ] Quote acceptance is followed by an authoritative re-read of quote and shipment state.
- [ ] Partner suspension, compliance withdrawal or capability revocation between assignment acceptance and customer quote acceptance blocks acceptance.
- [ ] No test is run against live customer data; use a safe staging environment with migration parity and controlled test identities.

## Safety and deployment boundary

No production or staging database writes, customer shipment submissions, quote acceptances, partner assignments, payment actions, secret changes, merge or deployment were performed for this audit. The current staging project has no migration parity; do not apply the pending migration proposals there or in production until a controlled staging environment and migration-history reconciliation are available.

## Exit decision

**Step 2 remains OPEN.** Existing server-side idempotency and client duplicate-submit protection reduce duplicate creation risk, but uncertain-outcome recovery is not complete. Implement the recovery lookup and request snapshot workflow, then run the positive and negative tests above before treating customer booking as fully operational.
