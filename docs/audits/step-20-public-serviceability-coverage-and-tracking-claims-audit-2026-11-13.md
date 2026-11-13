# Step 20 — Public serviceability, coverage and tracking-claim audit

**Date:** 2026-11-13  
**Branch:** `website/global-launch-readiness`  
**Scope:** Targeted public-facing review of about, network, air, ocean, road/rail, global coverage, market-readiness and tracking pages, plus the existing customer booking and tracking language. The repository contains over 1,000 HTML/JS/TS files; this is a high-risk public-surface audit, not a certification of every file.

## Executive result

The audit found public pages that still advertised global corridors, large verified-network counts, guaranteed airline space, instant escrow payouts, automated customs clearance and real-time telemetry as if already operating. Those claims were inconsistent with KRIM's actual partner-validation status and partner-direct commercial model.

The primary global-markets page was already appropriately explicit: global-ready architecture is not global service coverage; India is the initial commercial focus; routes are bookable only after providers, pricing, compliance, support and operational readiness are confirmed. That model is now reflected in the other audited public service pages.

## 1. Public pages corrected

### About
- Replaced unsupported secure-escrow execution claims in the meta description.
- Clarified that GPS telemetry, ePOD verification and spot-bid functionality are shown only when the relevant partner/integration supplies and verifies the data.

### Network
- Removed invented network scale claims: 1,250+ enterprise shippers, 8,400+ verified carriers and 140+ active trade lanes.
- Changed “Worldwide Freight Corridors” and “Primary Operating Corridors” to global network architecture / planned multimodal network.
- Clarified that displayed corridors are concepts, not confirmed operating services; partner credentials, capacity, route terms, regulatory checks and service availability require validation.

### Air freight
- Removed claims of priority airline booking, instant tariff calculators, guaranteed cargo space and automated spot bidding.
- Removed “Instant Escrow Payouts” and the unsupported Razorpay escrow release statement.
- Replaced with partner-confirmed capacity, schedule, cargo acceptance and pricing language; clarified that KRIM does not hold escrow or execute carrier payouts.

### Ocean freight
- Removed claims of automated customs documentation, encrypted carrier escrow, guaranteed FCL/LCL booking, automatic tariff calculation and instant Razorpay escrow release.
- Clarified that vessel space, schedules, rates, documentation, customs and handling require confirmation from qualified contracted partners.

### Global coverage
- Removed “140+ countries” operational coverage and active regional operating-zone claims.
- Reframed as global-ready network architecture and market-development regions.
- Clarified India-first activation and that other markets are subject to partner validation, legal review and operational activation.

### Road and rail
- Removed automated spot bidding, rail scheduling, escrow disbursement and Razorpay carrier-payout claims.
- Clarified that equipment, capacity, schedules, rates, tracking, rail/road hand-offs and transit times depend on partner confirmation.

### Root tracking page
- Changed “Real-Time Global Shipment Tracking” and “instantly across the KRIM network” to recorded shipment updates.
- Clarified that GPS, carrier telemetry and ePOD are displayed only when supplied and verified by a partner or enabled integration.

## 2. Pages that were already aligned

- `global-markets.html` clearly separates designed, configured, partner-validated and operationally activated markets.
- It states India is the initial commercial focus and international markets are partner-led expansion.
- It explicitly warns that a country or corridor shown in strategy is not a live coverage promise.
- The canonical `public/tracking.html` already describes recorded shipment events, warns users to keep tracking references private, and avoids promising GPS data when none is recorded.
- The canonical customer booking page already warns that geography search results do not confirm an active service and that serviceability/pricing/booking require confirmation.

## 3. CI results observed

For the latest reviewed commit `d71aa34040a724694026707e2eac2b16bfcd83df`:
- KRIM static link audit: **PASS** (run 43362290601).
- KRIM production smoke checks: **FAIL** (run 43362290641).

The smoke workflow's checked-in script still contains legacy assertions that treat the Razorpay freight checkout and payment-gated shipment confirmation as the required canonical launch path. That conflicts with the approved partner-direct launch mode and Step 15's fail-closed order-creation gate. The failure needs a deliberate test-suite update and review; it must not be “fixed” by re-enabling KRIM freight checkout or bypassing the new safety gate. The smoke failure is a launch blocker until the test contract is updated and the full suite passes.

## 4. Remaining risks / not tested

1. The public claims audit was targeted; the remaining 1,000+ code files have not all been individually reviewed.
2. Customer shipment confirmation and payment-verification pages still implement the historical KRIM-paid checkout sequence. That sequence is not compatible with the initial partner-direct model for new shipments and must be separated from historical payment reconciliation before release.
3. Partner verification, capacity, route-specific rate and support coverage are not yet sufficient to claim live nationwide or international service coverage.
4. No browser E2E test, provider test transaction, real partner booking, shipment dispatch, or customer-to-partner payment was executed in this step.
5. No production deployment, PR merge, database mutation, payment-provider call, refund, payout, webhook replay or secret/config change was performed.

## Status

**Public claims corrected across the audited service pages.** Static link audit passes. Production smoke remains failing due to an outdated checkout-oriented test contract and requires a separate safe update. KRIM is not yet cleared for live commercial operation or global service claims.
