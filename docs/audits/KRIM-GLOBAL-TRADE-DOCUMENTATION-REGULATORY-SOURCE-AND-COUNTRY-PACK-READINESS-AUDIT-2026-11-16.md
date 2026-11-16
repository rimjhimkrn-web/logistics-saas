# KRIM Global Trade Documentation, Regulatory Source Governance and Country Operating-Pack Readiness Audit — 2026-11-16

## Executive decision
**NO-GO for representing any country as operationally approved, advertising global trade-document clearance capability, or activating cross-border corridors.** The platform has a broad governance framework and 249 country pack shells, but no regulatory source records, no approved country controls, no approved country pack, no market readiness assessments approved, and no corridor compliance dossiers. The current data represents research scaffolding, not completed legal/operational coverage.

This audit is read-only. No database writes, RPC invocations, document submissions, legal opinions, provider calls, market activation or corridor changes were made.

## 1. Production evidence snapshot
Live production counts:

| Register | Rows | State |
|---|---:|---|
| Market catalogue | 6 | Catalogue records only |
| Country operating packs | 249 | All `research_pending` |
| Country pack controls | 4,482 | All 4,482 `pending`; all mandatory |
| Global market readiness requirements | 22 | All `draft` |
| Market readiness assessments | 82 | All `pending` |
| Regulatory source versions | 0 | No source versions registered |
| Regulatory source events | 0 | No review history |
| Network corridor catalogue | 7 | Catalogue candidates only |
| Corridor compliance dossiers | 0 | None created |
| Corridor compliance legs / controls / events | 0 / 0 / 0 | No evidence lifecycle |

There are 18 seeded country controls per pack (entity/legal eligibility, licensing, transport permits, tax, payments/FX, customs/trade, cargo admissibility, privacy, consumer marketplace, workforce, insurance, contracts, competition, cybersecurity, environment/facilities, accessibility, local operations and regulatory monitoring). All 4,482 have no source attached. The 22 global readiness requirements are still draft; they cover entity eligibility, licences, tax, payments/FX, privacy, sanctions/export controls, insurance/liability, workforce and other launch dependencies.

The five India customs requirement seeds remain a separate register and all are inactive/research-pending, as reported in the preceding customs audit. There is no conflict between the 249-country pack shell and the five India-specific customs research rows: neither constitutes approved country coverage.

## 2. Positive architecture and control design
- Regulatory sources distinguish official primary/secondary material, qualified legal/tax opinions, licensed-provider evidence and other references. Source records include jurisdiction, version, publication/effective dates, retrieval timestamp, SHA-256, evidence reference and review status.
- Source registration and review are routed through AAL2 platform-admin functions. Source review prevents the original source submitter from reviewing their own source. An official source cannot become `source_checked` without HTTPS URL and SHA-256; legal/tax review requires a separately registered qualified opinion and evidence reference.
- Country pack controls require resolved applicability, evidence, source and rationale before approval. The live function checks source jurisdiction, review state and effective dates; legal domains require a qualified legal/tax opinion that is legally reviewed. The reviewer cannot be the source registrant or source reviewer.
- Country pack approval requires every mandatory control to be approved with evidence, a source and rationale; it rechecks source jurisdiction, review state/effective dates, independent source registration/review, and prevents a control reviewer from approving the same complete pack.
- Market activation is separate from catalogue status. The server-side gate requires a current approved country pack, mandatory market assessments, reviewed sources/qualified opinions, active locations and verified partner capabilities.
- Corridor dossiers expand each corridor into origin, transit and destination jurisdictions, and seed a broad control set for each jurisdiction. Final activation requires every mandatory corridor control and every jurisdiction country pack to be approved.

These are meaningful safeguards in the database definitions. They have not been exercised through authenticated staging tests and do not create actual regulatory coverage by themselves.

## 3. P1 — Corridor approval does not revalidate source integrity
The live `krim_admin_set_corridor_dossier_status(..., 'approved_for_activation', ...)` checks that every mandatory corridor control is marked approved, has an applicability decision, source ID, evidence reference, reviewer note and unexpired control expiry. It also checks that every leg's country pack is approved and that mandatory pack controls are approved with evidence/source/rationale.

However, the final corridor approval routine does **not** re-join the source records to revalidate that each source:
- still exists and is not retired/rejected;
- remains in `source_checked` or `legal_reviewed`;
- is still jurisdiction-matched to the corridor leg;
- is currently effective (including `effective_from` and `effective_until`);
- has not become stale or otherwise invalid since the control was reviewed.

The corridor control review function checks the source review status and jurisdiction and checks `effective_until`, but it does not visibly reject a future `effective_from`. It also does not enforce the stronger source-reviewer independence checks present in the country-pack control review. This creates inconsistent assurance between the country pack and corridor layers.

**Required remediation:** use one shared server-side source-validity predicate for country and corridor approvals; enforce both effective dates, review status, jurisdiction, source type/legal-opinion rules and expiry at the moment of final approval and at every downstream activation/booking check. Ensure control reviewer separation is explicit and auditable. Do not approve any current dossier until this is tested.

## 4. P1 — Corridor dossier final approval does not prove an independent final approver
The corridor status function records `approved_by` but does not visibly compare the final approver with the control reviewers or dossier owner. Country pack approval explicitly blocks a control reviewer from approving the whole pack; corridor dossier approval does not provide the same explicit separation. This is especially important because the same platform-admin permission is used for dossier creation, control review and final approval.

**Required remediation:** require a distinct final approver (AAL2) from dossier owner and relevant control reviewers, preserve a reason and approval evidence, and record a complete immutable decision event. Define when a second reviewer is required for high-risk or regulated controls.

## 5. P1 — Market readiness assessment can be marked approved without a source-review join
The market assessment RPC requires AAL2 platform-admin permission, a rationale of at least 20 characters, an evidence reference for `approved` or `not_applicable`, and an optional future expiry. It validates that the requirement applies to the market and records an event/audit record. It does not itself require a linked regulatory source record, verified source status, source effective dates or a reviewer different from the source registrant. The separate market activation gate does check for reviewed sources and qualified opinions before eligibility, so an assessment alone should not activate a market. Nevertheless, the console's “approved” count can be mistaken for legal approval if shown without the separate source and pack gates.

**Required remediation:** bind assessments to one or more source-version IDs and, where relevant, a qualified opinion; require current jurisdiction and review status before an assessment can be approved; make not-applicable decisions carry an explicit applicability basis and independent approval; show “assessment recorded” rather than “market approved” until the complete activation gate passes.

## 6. P1 — Regulatory source lifecycle and freshness are incomplete at the integration layer
The source register has version, hash, retrieval and effective-date fields, but no source rows or event history exist. There is no demonstrated scheduled source monitoring, hash re-fetch, regulatory change alert, supersession process, source owner, or automatic invalidation of dependent country controls/market assessments/corridor approvals. A `next_review_at` field is not proof that review occurs.

The review transition guard checks that official sources have URL/hash before `source_checked`, and that legal review is based on a qualified legal/tax opinion. The source review workflow is not a substitute for a live monitoring process. Future-dated source effectiveness should block current approval consistently at every layer.

**Required remediation:** add a monitored source owner, source retrieval evidence, canonical source version and hash, review SLA, next review enforcement, supersession/retirement event, and dependency invalidation/re-evaluation. Keep all dependent gates blocked when a source is expired, superseded, withdrawn or overdue for review.

## 7. P1 — Country pack completeness is a framework, not jurisdiction-specific legal coverage
The 18 controls per country are broad domains, not a jurisdiction-specific statutory requirement catalogue. There are 249 packs and 4,482 mandatory controls but zero sources. The 22 global requirements are draft and have no approved assessments. No country pack has an identified legal owner in the live counts reviewed. The current pack model can support review, but it does not demonstrate that every relevant local requirement has been identified, including product-specific restrictions, local licensing, customs, taxes, privacy transfers, workforce, insurance, consumer and environmental rules.

**Required remediation:** prioritize India as the first market activation, then add only jurisdictions/corridors with a real commercial need. For each service actually offered, obtain current official primary sources and qualified local legal/tax opinions; identify applicability by entity role, principal/agent model, transport mode, cargo, route and customer type. Record exemptions with legal basis. Do not approve a pack by treating a generic domain checklist as exhaustive law.

## 8. P1 — Public international trade document page contains fabricated-looking live status
`public/documents/international-trade-documents.html` contains a hard-coded trade declaration ID, a EUR 1,240,000 invoice, Incoterms, HS chapters, a “Chamber of Commerce Verified” certificate, and a green “Customs Cleared” / automated regulatory “Approved” presentation. No corresponding customs cases, documents, broker assignments, declaration submissions or authority clearance evidence exist in production. The page does not clearly label these values as fictional sample content.

This is a trust and misrepresentation risk. A visitor may interpret the sample as a real KRIM shipment or proof that KRIM provides customs clearance.

**Required remediation:** remove the fabricated transaction/status, or clearly mark the entire screen as a non-operational illustrative demo with synthetic data and a persistent warning that KRIM does not issue customs clearance. Prefer a neutral document checklist and evidence workflow. Never display green “cleared/approved” status without a real, verified authority-issued evidence record.

## 9. P1 — Operational readiness must be derived, not inferred from catalogue status
Six markets and seven corridor candidates exist, but catalogue flags are not regulatory approval. The market gate is designed to combine country pack, assessments, reviewed sources, locations and verified partner capabilities. Corridor activation combines every jurisdiction pack and corridor control. None of these dependencies is currently met. Do not show country coverage, corridor availability, customs capability or serviceability from the existence of a market, country pack, country row, corridor row or generic document template.

## 10. Staging acceptance tests — not run
1. Source registration and source review enforce submitter/reviewer separation.
2. Official primary source cannot become source-checked without URL, hash and retrieval evidence.
3. Qualified legal/tax opinion has evidence reference, reviewer qualification and independent review.
4. Future-effective, expired, retired, rejected or superseded source cannot support any approved control.
5. Country pack approval fails if even one mandatory control is missing, pending, unsupported, expired or sourced from another jurisdiction.
6. A control reviewer cannot approve the same complete country pack.
7. Corridor approval revalidates all source rows at final approval, including effective-from and effective-until.
8. Corridor control reviewer and final dossier approver are distinct where policy requires.
9. Market assessment cannot be mistaken for market activation; source and pack blockers remain visible.
10. Not-applicable decisions require scope-specific legal rationale and independent approval.
11. Any source change invalidates dependent market/country/corridor approval and downstream shipment eligibility.
12. A country pack with an incomplete control inventory cannot be approved.
13. A corridor with a missing origin, transit or destination pack cannot be approved.
14. A corridor control cannot be approved from a source for a different jurisdiction.
15. A route or shipment cannot use a corridor after a source/control/pack expires or is suspended.
16. Public trade-document pages contain no fictitious customer data or unsupported customs-clearance claims.
17. Cross-tenant and non-AAL2 access to all admin registers and mutations is rejected.
18. Audit-event failure causes the state mutation to roll back.

All tests remain unexecuted. No production RPCs were invoked.

## 11. Remediation order and release decision
**NO-GO** for country/corridor activation, global trade-document clearance claims, live customs filing, or global operating coverage.

Priority:
- **P0/P1:** reconcile the source-validity and independent-review requirements between country and corridor approval; ensure final corridor approval revalidates every source.
- **P1:** bind market assessments to source evidence and label them as assessments, not approvals of market operations.
- **P1:** establish real regulatory source ownership, version/hash monitoring, review expiry and dependency invalidation.
- **P1:** prioritize a complete India country operating pack with qualified local legal/tax review for the exact KRIM intermediary model and each service actually launched.
- **P1:** remove or clearly relabel the hard-coded “Customs Cleared” international trade demo.
- **P1:** run the 18 staging acceptance tests before any country/corridor approval workflow is used for operational decisions.
- **Later:** build additional country packs only when real partners, routes and customer demand justify the cost of legal validation.

## Change boundary
Read-only production and source audit only. No DDL/DML, migrations, RPCs, external sources registered, market/corridor approvals, document uploads, provider integrations or live trade activity. Production/repository migration-history mismatch remains unresolved; do not apply/replay/baseline/squash migrations or corrective production DDL until full schema-manifest reconciliation and separate authorization.
