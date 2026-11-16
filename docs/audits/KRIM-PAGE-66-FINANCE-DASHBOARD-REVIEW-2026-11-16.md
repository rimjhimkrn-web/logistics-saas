# KRIM Page 66 — Finance Dashboard
Date: 2026-11-16

## Canonical page
`app/finance/index.html` — Finance & Treasury Command Centre. The legacy `public/finance/finance-dashboard.html` redirects to this authenticated workspace.

## Access and current data posture
- Requires authenticated session, active finance-organization membership and `finance.view`.
- Invoice, settlement and payment-order datasets are intentionally withheld pending tenant-scoped legal-entity authorization and partner-direct operating-model review.
- Legacy revenue reporting remains withheld because it is not sufficiently organization-scoped.
- The page provides navigation to finance modules but does not post journals, reconcile bank/provider records, issue invoices, collect freight funds, or execute partner payouts.

## Changes
Commit: `694fd80b1c61d0a5a20af380687b9cf5b970b227`
- Corrected the dashboard status from “partial data access” to “restricted data”.
- Clarified that the three withheld finance datasets are intentionally restricted, not failed live queries.
- Preserved the no-write posture and explicit withholding of unscoped legacy revenue reporting.

## Commercial and financial boundary
For the initial non-custodial operating model, customers pay logistics partners directly. KRIM must separately invoice/collect only its own agreed referral or coordination fee. Freight GMV, partner freight collections and partner payouts must not be reported as KRIM revenue.

## Verification
No invoice, payment, refund, settlement, payout, journal or ledger record was created or modified. No provider or bank reconciliation was performed. Production finance policy/function alignment remains subject to migration-history reconciliation.
