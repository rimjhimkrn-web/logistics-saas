# KRIM Customer Acquisition, CRM Conversion and Commercial Handoff — Production Verification Addendum
**Date:** 16 November 2026  
**Scope:** Re-verified live production CRM/admin control plane against repository source, public intake RPCs, inquiry qualification/linkage, follow-up state, RLS and commercial conversion records.

## Executive decision
**DO NOT treat the current CRM funnel as production-ready for customer conversion.** Public enquiry capture and a restricted admin queue exist, but the actual customer conversion and fee earning lifecycle is not established. A new deployment drift was found: the live admin Edge Function still accepts a `converted` follow-up outcome even though the checked-in source and UI have removed it.

This was a read-only audit. No enquiries were submitted, no customer records were created, no messages sent, and no production code/schema/data changed.

## 1. Live funnel inventory
Production tables rechecked in the prior pipeline audit remain empty for:
- Public contact enquiries
- Customer accounts
- Customer acquisition profiles and events
- Customer qualification cases
- Customer service requests
- Inquiry follow-ups
- Customer referrals
- Canonical customer consent ledger
- Partner match runs/results
- Partner quotes and shipment partner assignments

Existing partner-side counts from the previous audit (3 historical opportunities, 1 verification case, 1 capability) are not evidence of an active verified partner or available service capacity. The 3 opportunities were previously identified as expired/cancelled.

## 2. Public intake and canonical qualification defect
The live public submission RPC `krim_submit_public_contact_inquiry` creates, in one transaction:
1. A public contact inquiry.
2. An acquisition profile with `organization_id = NULL`.
3. An acquisition-discovered event.
4. A standalone pending qualification case.
5. A founder Telegram outbox event.

After the transaction commits, the public Edge Function separately calls `krim_internal_link_public_inquiry_to_service_request`. That function creates a general customer service request if one does not already exist, then calls `krim_internal_qualify_customer_request` when the request has no linked qualification case.

**P0 — duplicate qualification path:** the first pending qualification case is already created by the public submission RPC, but the later qualification engine inserts another qualification case and links that second case to the service request. The original case may remain orphaned. The linkage function is idempotent for its service-request reference, but this does not make the first qualification case canonical. No live rows exist to observe a real example, but the two function definitions establish the duplicate-write path.

**P0 — linkage failure is not durable:** if the post-commit service-request linkage RPC fails, the Edge Function logs the failure but still returns successful enquiry receipt. The saved inquiry and initial profile/case remain, but no durable linkage retry state or reconciliation record was demonstrated.

**Required:** choose one canonical qualification case per inquiry/request, create/link it exactly once, and persist linkage state (pending/linked/retry/dead-letter) with a bounded reconciler. Preserve the original enquiry if a downstream workflow fails.

## 3. Admin access and data visibility
The deployed `global-admin-control` Edge Function is ACTIVE version 27 and requires:
- Authenticated user.
- AAL2 assurance.
- Active platform_admin or platform_superadmin role assignment.
- Server-side service-role reads/writes.

Its inquiry action returns a limited set of enquiry fields; status updates and follow-up notes create audit events. This is an appropriate restricted control-plane pattern, but the live endpoint is not the same thing as an independently tested end-to-end CRM journey.

**P0 — acquisition profile visibility mismatch:** public-created acquisition profiles have NULL organization_id. The inspected profile RLS policy relies on organization access for the row's organization_id. A NULL organization binding does not satisfy the organization membership predicate. Do not solve this by broadening authenticated RLS or exposing prospects to all logged-in users. Continue to use a dedicated AAL2 platform-admin endpoint for lead PII, or design an explicit least-privilege prospect ownership model.

## 4. New production deployment drift: follow-up “converted” outcome
The repository file `supabase/functions/global-admin-control/index.ts` at commit source `cc494553db6e8000cb081dbb27584e5d374e0a4d` no longer contains the `converted` outcome. The current enquiry-management UI also removed it and explains that an internal follow-up is not a commercial conversion.

However, the live Supabase Edge Function `global-admin-control` version 27 still contains:
`allowed=['pending','contacted','qualified','not_interested','converted']`

The live database `krim_inquiry_followups_outcome_check` constraint also still permits `converted`.

**P0 — misleading CRM semantics remain reachable through the deployed API:** an authorized platform admin can still submit `outcome=converted` directly to the live endpoint even though the UI hides that option. This can incorrectly count a follow-up as a converted customer without a customer account, completed shipment, signed referral agreement or KRIM fee receipt.

**Required:** after migration history reconciliation, deploy the checked-in corrected Edge Function and add a forward-only database constraint/state transition that removes the ambiguous follow-up outcome. Before any such change, verify no existing rows use the value and reconcile all migration history. Do not use the UI's removal as proof that the live API is fixed.

## 5. Consent and data minimisation
The public intake requires `privacy_consent=true` and writes a timestamp plus fixed privacy notice version onto the inquiry. It also copies consent status into profile/event metadata. But the dedicated `krim_customer_consents` table has zero rows and is not populated by the public submission RPC.

The current checkbox proves acknowledgement of the stated privacy notice; it does not establish marketing consent or permission for promotional follow-up. Founder operational Telegram alerts are separate from customer marketing.

Attribution is currently appended to free-text message rather than persisted as structured fields. Enquiry category, contact phone, country/region and shipment reference are also not first-class intake columns in the inspected public inquiry schema. The database requires an organization string, so the UI/edge path uses an “Individual customer” placeholder when blank; this is not a durable individual-vs-business customer model.

**Required:** after schema recovery, add a purpose-specific immutable consent evidence record with notice version, actual purpose, timestamp, source and withdrawal status; add structured and validated attribution and contact fields; keep free-text message separate. Do not infer consent from privacy-notice acknowledgement.

## 6. Follow-up workflow and customer communication
The admin endpoint can list follow-up history, add internal notes and schedule future follow-up reminders. The reminder scheduler creates founder-only Telegram outbox entries and explicitly records `customer_contact_sent=false`. This is good separation: scheduling an internal reminder does not claim a customer was contacted.

The follow-up API's deployed `converted` allowlist is inconsistent with the repository and UI as noted above. No follow-up records exist in production, so SLA, ownership, contact attempt, outcome and customer response history have not been proven in operation. No general customer email/WhatsApp follow-up delivery path was demonstrated.

## 7. Commercial conversion and KRIM revenue gate
The current platform does not demonstrate the full sequence:
- Qualified customer and verified decision-maker.
- Complete shipment/service requirements.
- Current route/corridor/market/customs approvals.
- Verified partner capability, compliance and capacity.
- Partner quote and customer acceptance.
- Customer contract with and direct payment to the logistics partner.
- KRIM partner referral/coordination agreement and attributed referral.
- Evidence KRIM performed the agreed service.
- KRIM fee invoice and actual fee collection.

The customer referral, fee allocation and shipment revenue records remain empty in the prior production audit. Legacy freight commission, partner payout and settlement systems must not be used for the lean partner-direct model.

**Revenue recognition rule:** KRIM revenue is only the separately agreed and actually collected KRIM referral/coordination fee, supported by partner agreement, referral attribution, evidence of service, invoice and collection. Partner freight price, freight GMV, partner freight receipts and shipment value are not KRIM revenue.

## 8. Priority corrections and safe release order
1. Reconcile production migration history with repository before any DDL/RPC change.
2. Deploy repository version of `global-admin-control` only after checking the exact diff and staging test; verify live version no longer accepts `converted`.
3. Remove `converted` from the database follow-up outcome constraint through a forward-only reviewed migration after checking existing values.
4. Make inquiry-to-service-request linkage durable and idempotent; create exactly one canonical qualification case.
5. Add a secure, explicit platform-admin prospect/profile read path and keep raw lead PII hidden from ordinary authenticated users.
6. Add purpose-specific consent ledger and structured attribution/intake fields.
7. Build commercial conversion stages that require evidence, not manual status labels: partner verified, corridor eligible, capacity confirmed, customer accepted, service completed, referral earned, fee invoiced, fee collected.
8. Stage-test duplicate intake, retry-after-timeout, qualification uniqueness, linkage failure/recovery, admin MFA/role access, cross-tenant denial, direct API outcome validation, consent withdrawal, referral attribution and fee collection evidence.
9. Only then run a controlled end-to-end test with explicit authorization.

## 9. Evidence reviewed
- Live deployed `global-admin-control` Edge Function version 27 source.
- Repository `supabase/functions/global-admin-control/index.ts` source at the checked-in commit above.
- Live `krim-public-contact-inquiry` Edge Function source and live public intake/linkage/qualification/follow-up RPC definitions.
- Live follow-up table check constraint.
- Live CRM table schemas, RLS policies and funnel counts.
- `public/growth/enquiry-management.html`, `public/growth/acquisition-command.html`, `public/growth/customer-conversion.html`.
- Prior report `docs/growth/KRIM-PUBLIC-ENQUIRY-TO-CUSTOMER-ACQUISITION-PIPELINE-AUDIT-2026-11-16.md`.

## Release boundary
No production changes were made. Production migration-history mismatch remains unresolved. Do not deploy the Edge Function, alter follow-up constraints, or change qualification RPCs until that reconciliation is complete and the change is verified in staging.
