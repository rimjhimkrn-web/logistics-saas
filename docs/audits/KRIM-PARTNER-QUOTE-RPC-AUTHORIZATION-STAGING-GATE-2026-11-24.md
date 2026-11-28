# Partner quote RPC authorization and staging ACL gate — 2026-11-24

Scope: read-only production/staging function comparison plus proposed, unapplied ACL repair. Repository: `rimjhimkrn-web/logistics-saas`; branch: `feat/notification-recipient-resolver-draft-2026-11-24`.

## Confirmed active call path
- `public/partner/submit-quote.html` directly invokes `client.rpc("krim_submit_partner_quote", ...)`.
- Exact overload: `public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)`.
- Production: authenticated EXECUTE = true; anon = false.
- Staging: authenticated EXECUTE = false; anon = false; service_role = true.
- Both definitions are SECURITY DEFINER, owned by postgres, and set an empty search_path.

## Function authorization review
Staging definition was inspected in full and compared with production. Both require a non-null `auth.uid()`, identify the caller's active partner organization through active membership, require registered-business mode, active organization, verified active capability, verified/approved partner status, current lifecycle/compliance states, and `quote.create` permission. The staging version additionally calls `private.krim_partner_compliance_is_current(o.id)`. It locks the open opportunity row, checks deadline/award state, excludes customer self-bidding and unsupported multi-leg shipment-wide bids, checks route capability and active currency, then writes/updates only the caller's resolved partner quote and an audit event.

The function is SECURITY DEFINER, so the body checks are the decisive tenant boundary. The inspected body does not accept a caller-supplied partner organization ID; it resolves the organization from `auth.uid()` and active membership. This materially reduces the risk of an IDOR-style organization substitution.

## Decision
The staging ACL mismatch is a confirmed partner-bidding blocker. The reviewed body supports a narrowly scoped authenticated EXECUTE grant, with PUBLIC and anon explicitly denied. A proposed guarded SQL file is included at:

`docs/proposed-migrations/20261124_restore_authenticated_partner_quote_submission.sql`

The guard refuses to proceed if the exact overload, SECURITY DEFINER mode, or key authorization markers differ. It changes no function body or business data.

## Verification status and remaining gate
- Completed: source call-site trace; full production/staging function body comparison; exact signature and role privilege comparison; review of membership, capability, compliance and permission gates in the function body.
- Not completed: positive own-organization submission and negative foreign-organization submission against representative staging partner fixtures.
- Staging currently has no verified active partner onboarding/capability dataset, so a real legitimate bid cannot be tested without introducing synthetic business data. No synthetic partner, capability, compliance evidence, opportunity or quote was inserted.
- Therefore the proposed ACL migration has **not** been applied to staging or production. The migration remains gated until a safe, isolated rollback-only test environment or approved representative staging fixtures are available.
- No real bid, quote award, payment, or external notification was created or sent.

## Adjacent RPCs
- `krim_submit_partner_onboarding_global_v2`: no active caller found in inspected current onboarding routes; no grant proposed.
- `krim_award_leg_partner_quote(bigint)`: caller not established by targeted source trace; migration source grants authenticated, staging denies. Full call graph and authorization review remain required before any ACL change.
