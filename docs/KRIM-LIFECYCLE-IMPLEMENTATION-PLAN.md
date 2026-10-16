# KRIM Lifecycle Implementation Plan

Status: active implementation plan  
Branch: `feature/krim-lifecycle-wiring`  
Frontend: GitHub Pages static HTML/JS  
Backend: existing Supabase project

## Working rules
- Preserve the existing KRIM visual design; make targeted edits rather than replacing whole pages.
- Reuse existing pages and backend contracts; do not create duplicate pages or competing payment/shipment implementations.
- Never expose service-role keys, payment secrets, or webhook secrets in browser code.
- A page is not complete merely because its file exists.
- Do not report a lifecycle complete until its backend calls, authorization, error states, and end-to-end behavior are verified.
- Keep privileged Control Centre pages out of public navigation.

## Confirmed foundations
- The repository already has hundreds of frontend files covering customer, partner, enterprise, auth, operations, compliance, finance, and developer areas.
- Supabase already has global KRIM tables and authenticated RPCs for shipment creation, quote creation/acceptance, shipment transitions, and customer-organization provisioning.
- `krim_provision_customer_organization(p_legal_name text)` requires an authenticated user and creates the organization/member relationship server-side.
- Browser code must use the public publishable key only.
- The deployed payment function inventory includes `create-razorpay-order`, `create-global-razorpay-order`, `verify-razorpay-payment`, `razorpay-webhook`, and `process-payment--`. Do not assume `process-payment` exists.

## Implementation sequence
1. Shared GitHub Pages routing and real customer signup.
2. Partner registration, verification, capacity, load marketplace, assignment, delivery proof, and settlement.
3. Customer address book, quote request/acceptance, shipment creation, tracking, ePOD, invoice, and support.
4. Payment checkout using the exact deployed function contracts; remove client-controlled freight amounts and false success states.
5. Enterprise, warehouse, forwarding/customs, integrations, AI, analytics, and global market workflows.
6. Authorization, tenant isolation, mobile navigation, error handling, duplicate-request protection, and end-to-end tests.

## Acceptance checklist
- [ ] Homepage Get Started works under the GitHub Pages project path.
- [ ] Signup creates a real Supabase Auth user.
- [ ] Email callback provisions the customer organization with the authenticated RPC.
- [ ] Login opens an existing workspace using the correct base path.
- [ ] High-priority links resolve to real files.
- [ ] Shipment, quote, and payment workflows pass end-to-end tests.
- [ ] Security and tenant-isolation tests pass.
