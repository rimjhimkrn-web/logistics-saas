# Phase 00 — Customer booking and partner quote UI-to-RPC wiring audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: static page inspection plus read-only RPC source/ACL parity checks. No browser sign-in, form submission or database writes.

## Canonical routes identified

- `public/customer/shipment-create.html` is a redirect-only compatibility page. It forwards to `public/shipper/booking-request.html`; it does not create a shipment.
- `public/shipper/booking-request.html` contains the actual customer booking form and calls `krim_create_global_shipment_idempotent`.
- `public/partner/submit-quote.html` contains the partner bid form and calls `krim_submit_partner_quote`.
- `public/partner/services-capabilities.html` calls `krim_partner_submit_service_capability_v2`.
- `public/customer/quote-acceptance.html` is a redirect-only compatibility page to the Customer OS quote acceptance workflow.
- `public/driver/pod-submission.html` redirects to the Driver Operations proof-of-delivery workflow.

This confirms that the legacy paths are not themselves the transaction forms; tests must exercise the canonical destinations and preserve query parameters.

## Customer booking RPC

`krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid)`:
- Exists in both Production and Staging.
- Source fingerprint identical: `f7d1125b37bd6fbddd69f60defdf082c`.
- SECURITY DEFINER with empty search_path.
- EXECUTE granted to authenticated and service_role.
- Static page references confirm the booking UI invokes this RPC.

Source/ACL parity is encouraging, but the actual form flow, idempotency behavior, validation, upload handling, and transaction result have not been browser-tested.

## Partner quote RPC — critical Staging mismatch

`public/partner/submit-quote.html` calls `krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)` from the browser.

Production:
- Fingerprint `bf96fd4c59acb3974df74e27adea42e1`.
- SECURITY DEFINER.
- EXECUTE granted to authenticated and service_role.

Staging:
- Fingerprint `84b3d5c1f4cb3b3e19754757ea61f808`.
- SECURITY DEFINER.
- EXECUTE granted only to postgres and service_role; authenticated is not granted EXECUTE.

The Staging function body also adds `private.krim_partner_compliance_is_current(o.id)` to the partner eligibility test and returns a stricter failure message. Its function body otherwise uses active organization membership, registered-business partner status, active verified capability, current organization verification/lifecycle/compliance, quote.create permission, active currency, open opportunity, deadline, shipment coverage, and excludes self-bidding and multi-leg shipment-wide bidding.

**Impact:** the current browser-based partner quote submission UI cannot invoke this RPC as an authenticated Staging user with the inspected ACL. This is a direct staging E2E blocker. Do not grant execution blindly: review the intended permission model and source/migration history, then make the intended authenticated grant explicit in a reviewed Staging migration if appropriate. Production already has the grant.

## Other safeguards observed

- Partner capability submission page calls the versioned v2 RPC.
- The underlying capability RPC requires authenticated partner manager permission, active registered-business organization, current compliance, active transport mode, valid country, bounded capability values and evidence objects owned by the submitting user in the private bucket.
- New capability rows are created inactive and pending verification.
- The driver POD route is a redirect; the canonical Driver Operations page must be browser-tested separately.

## Test plan once Staging ACL and synthetic fixtures are ready

1. Sign in as synthetic customer and load canonical booking route.
2. Validate required fields, route/country selection, transport mode, weights, currency and market activation.
3. Submit once and verify exactly one shipment and idempotency record; retry same idempotency key and verify no duplicate.
4. Repeat with missing permission, wrong organization, invalid/inactive market, invalid route and duplicate/concurrent submission.
5. Sign in as synthetic verified partner and submit a bid; verify row and audit event.
6. Verify Staging currently rejects at the RPC privilege boundary before changing any grant.
7. After reviewed ACL correction, test unverified partner, expired opportunity, invalid currency, self-bid, uncovered route/weight, duplicate/concurrent bid and multi-leg restrictions.
8. Verify accepted partner quote → assignment → customer quote acceptance → shipment confirmation, including rollback on any failed stage.
9. Test POD through canonical Driver Operations page with correct driver, wrong driver, wrong assignment, invalid file and duplicate submission.
10. Verify notification evidence at each event; current notification audits show workflow preparation is not provider delivery.

## Evidence boundary

Static HTML/JavaScript source inspection and read-only database function/ACL queries only. No form was submitted, no RPC invoked, no user created, no grant changed, no file uploaded and no provider called. Production and Staging remained unchanged.
