# Partner opportunity exact-corridor gate — remediation specification

**Status:** prepared from read-only live inspection; not a migration and not applied.
**Production impact:** none. No shipment, opportunity, quote, assignment or partner record was created or modified.

## Confirmed live function
`public.krim_create_partner_opportunity(bigint,timestamptz,text)` is SECURITY DEFINER. It:
- verifies authenticated user, shipment access and `quote.create`;
- requires draft/quoted shipment and a non-empty requested transport mode;
- rejects active multi-leg plans because leg-specific sourcing is not implemented;
- checks endpoint locations/countries and catalogue markets marked active;
- reuses an existing open opportunity or creates a new one and transitions draft shipment to quoted.

## P0/P1 gap
The opportunity RPC's own endpoint-market query checks `krim_markets.is_active/status`, but does not itself join `krim_market_activation_controls` or re-run `krim_internal_market_activation_gate`. This is weaker than the authoritative helper `private.krim_market_country_operational(bigint)`, which requires an active activation-control row and an eligible activation gate.

The RPC also does not select and validate one exact `krim_network_corridors` record matching both locations/countries and the shipment's requested transport mode, nor does it independently require an approved current `krim_corridor_compliance_dossiers` record with all applicable mandatory controls reviewed and unexpired.

The partner matcher has related findings: stored compliance status can be stale, capacity isn't checked, and an opportunity may be created even when there are no eligible candidates. Those are separate gates and must not be conflated with corridor approval.

## Read-only production evidence
- `krim_network_corridors`: 7 records, all `draft`.
- `krim_corridor_compliance_dossiers`: 0 records.
- `krim_corridor_compliance_controls`: 0 records.
- Market activation controls were previously inspected as blocked for all 6 markets.
- No approved corridor currently exists; the gate must fail closed.

## Required correction before partner sourcing
1. Replace the endpoint catalogue-only query with the canonical market operational helper for both endpoints.
2. Require exactly one current corridor match for origin/destination (including reverse direction only when explicitly configured), and requested mode.
3. Require approved dossier, valid review window, and a complete set of applicable mandatory controls; fail closed on zero controls or missing sources.
4. Revalidate current source status/effective dates and jurisdiction, not only stored dossier approval.
5. Run partner eligibility against current compliance, approved service-area coverage and live capacity/commitments/reservations.
6. If no eligible partners exist, do not create an actionable/open opportunity; return a non-actionable coverage result or explicit no-match response.
7. Preserve the existing multi-leg rejection until leg-specific sourcing is implemented.
8. Add concurrency and replay tests: duplicate calls, expired deadline, conflicting service tier, route suspension between request and commit, capacity race, no eligible partner, and cross-tenant access.

## Deployment blocker
Do not write a replacement function yet. Production has zero dossiers and controls, so accepted status vocabularies, effective-date/source joins, and canonical approval semantics must first be reconciled against the protected sanitized schema manifest and repository migration history. No production DDL until that reconciliation and staging verification are complete.

## Staging acceptance criteria
- Catalogue-active but activation-control-blocked endpoint: denied.
- Endpoint markets operational but exact corridor absent/draft: denied.
- Corridor approved but mode not in dossier/leg mode codes: denied.
- Any applicable mandatory control pending/rejected/expired/source-invalid: denied.
- No eligible current partner/capacity: no actionable opportunity created.
- Exact approved corridor, current controls, eligible partner and capacity: opportunity can be created and is auditable.
- Existing opportunity replay returns same record only when canonical request parameters match.
