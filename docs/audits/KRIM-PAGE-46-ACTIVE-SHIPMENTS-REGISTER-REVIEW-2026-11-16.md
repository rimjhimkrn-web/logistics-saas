# KRIM Page 46 — Active Shipments Register Review
Date: 2026-11-16

## Scope and canonical route
Page 46 is the customer Active Shipments register. The legacy public route `public/shipper/active-shipments.html` is a compatibility redirect to the canonical organization-scoped register at `public/customer-os/customer-services/shipment-list.html`. The canonical page is therefore the implementation audited for this page number.

## Verified implementation
- Requires an authenticated Supabase session; unauthenticated users are redirected to login with the return path.
- Loads active organization memberships for the signed-in user and restricts eligible organizations to active customer, shipper or enterprise types.
- Queries `krim_shipments` only for those customer organization IDs; RLS remains an additional backend boundary.
- Resolves origin and destination labels from location records.
- Supports search, status filtering, sorting and client-side pagination over the latest 100 records.
- Escapes database-derived strings before inserting them into HTML.
- Uses a finite status allowlist: only exact `delivered` / `delivery_completed` count as delivered; known request/movement states count as active; unknown, cancelled and closed states are routed to attention rather than falsely counted as delivered.
- Links to canonical shipment details, visibility, pickup/custody and quote pages. These links do not themselves create or mutate shipment records.

## Change in this pass
Commit: `b4c0d64952d15a980a23acf7888ca5ef614519ce`

- Added safe date formatting so malformed or absent timestamps render as an em dash rather than “Invalid Date”.
- Changed the shipment-list estimate label to **Recorded delivery estimate (not live ETA)** and only renders it when the timestamp parses. This avoids implying a verified live arrival prediction.

## Boundaries and outstanding verification
- The register displays at most 100 latest shipments; it is not server-side pagination and does not claim to be a complete historical archive.
- No live GPS, carrier scan, customs clearance, partner assignment, capacity commitment or delivery guarantee is inferred from a shipment row.
- A real authenticated customer-session/browser verification was not performed in this pass. GitHub Actions static-link, production-smoke and Pages deployment checks are being used for repository-level verification; they do not prove every RLS policy or live customer journey.
- The compatibility route remains a redirect; the canonical register is the source of truth.
- Original Page 46–103 source inventory was not available in the repository search performed for this pass; numbering here follows the user's explicit current sequence.

## Page 46 status
**Code review and safe correction complete; automated checks pending.** Do not interpret this as end-to-end production certification.
