# KRIM Logistics — First Commercial Lane Rate Approval

**Purpose:** collect the real commercial inputs required to configure the first live customer rate in KRIM. This is a blank approval template, not a price list. Do not activate a rate card while required fields are blank.

## 1. Lane and service

- Origin country / city / service area:
- Destination country / city / service area:
- Domestic or cross-border:
- Transport mode (ROAD or AIR):
- Service tier (surface_express, air_priority, or heavy_haul):
- Service capacity confirmed by partner? (Yes/No; evidence):
- Expected pickup/lead time and service exclusions:

## 2. Partner and cost evidence

- Legal partner name:
- Partner organization ID in KRIM:
- Verification and compliance status checked by:
- Partner contact and date of written quote:
- Partner buy price (numeric):
- Currency:
- Charge basis (per shipment, per kg, distance, volume, or another explicitly defined basis):
- Included services:
- Exclusions and surcharges:
- Evidence reference (quote/document ID; store the document securely, not in a public repository):

**Rule:** a test/sample account or partner with pending verification/compliance is not eligible to substantiate a live rate.

## 3. KRIM selling price and margin approval

- KRIM platform fee or markup method:
- Approved fee/markup value:
- Expected KRIM gross margin amount:
- Expected KRIM gross margin percentage:
- Minimum customer charge:
- Approver name/role:
- Approval date and evidence reference:

## 4. Tax and effective dates

- Tax/GST treatment reviewed by a qualified person? (Yes/No; reviewer/reference):
- Other mandatory fees or surcharges:
- Rate effective from (with timezone):
- Rate effective until / review date:
- Currency and rounding rule:
- Refund/cancellation terms confirmed? (Yes/No; policy reference):

## 5. Activation checklist

Mark each item only after verification:

- [ ] Partner is genuinely onboarded, verified, compliant, and commercially enabled.
- [ ] Partner's dated buy-rate evidence is recorded.
- [ ] Lane, mode, tier, and charge basis are unambiguous.
- [ ] KRIM fee/margin has an approval record.
- [ ] Tax, surcharges, and customer-facing terms have been reviewed.
- [ ] Rate card is created as **draft** in Supabase.
- [ ] A test shipment on this exact lane produces the expected quote.
- [ ] Persisted quote amount, currency, expiry, checkout amount, and payment order match.
- [ ] Approval is recorded and the card is activated through the authorized admin workflow.
- [ ] Post-activation quote test passes.

## 6. Decision

- Decision: Pending / Approved / Rejected
- Decision owner:
- Date:
- Notes:

**Do not use demo amounts, zero-value drafts, guessed market rates, or unverified partner data as live commercial pricing.** Payment testing and launch acceptance remain separate checks even after a rate card is approved.
