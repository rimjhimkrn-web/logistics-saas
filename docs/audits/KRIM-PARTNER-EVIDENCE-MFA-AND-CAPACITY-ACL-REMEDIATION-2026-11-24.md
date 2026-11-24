# Partner evidence MFA UX and capacity RPC ACL remediation — 2026-11-24

## Implemented on the draft PR branch

### Capacity evidence upload
- Added a pre-upload MFA gate to `public/partner/capacity-resources.html`.
- It checks for a verified TOTP factor and current authenticator assurance level.
- If no verified factor exists, the user is routed to `auth/mfa-enroll.html` with a return path to the Partner Workspace.
- If a factor exists but the session is AAL1, the user is routed to `auth/mfa-challenge.html`.
- The check occurs before any Storage upload, so an AAL1 session does not create partial evidence objects.

### Service-area evidence upload
- Added the same verified-factor and AAL2 check before uploads in `public/partner/service-coverage.html`.
- Replaced timestamp + `Math.random()` object naming with `crypto.randomUUID()`.
- Object keys now use the organization/user/service-area prefix and a normalized MIME-derived extension. Original client filenames are no longer embedded in object keys.

### Capacity RPC ACL proposal
- Added `docs/proposed-migrations/20261124_restore_authenticated_partner_capacity_rpc.sql`.
- It targets only the exact `krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text)` overload.
- The preflight refuses to proceed if the function is missing, not SECURITY DEFINER, lacks explicit search_path configuration, or is missing key auth, permission, compliance, evidence-storage and pending-review markers.
- It revokes PUBLIC/anon and grants EXECUTE to authenticated and service_role, with post-change assertions.
- Added `tests/sql/partner-capacity-rpc-acl-assertions.sql`.

## Verification status
- GitHub contents API confirmed both frontend files were updated and the proposal/test files were created on the draft branch.
- A fresh PR metadata read confirmed PR #245 remains draft and its latest head is `c98bac7eb6d9dde1f1f5814bc6f2c2da4a82b9de`.
- The workflow-run lookup returned no runs for that latest head at the time of this report. CI status is therefore **not yet verified**.
- No browser test, MFA enrollment/challenge round-trip, Storage API upload, isolated PostgreSQL migration execution or live partner submission was performed in this stage.
- The ACL assertion SQL has not been executed.

## Deployment boundary
No production or staging SQL was applied. The staging migration ledger is materially unreconciled, so this proposal must not be applied manually or outside the canonical migration recovery path. Production already grants authenticated EXECUTE on this exact overload; no production grant change is needed. The staging mismatch remains an acceptance blocker until the versioned ACL repair can be safely applied and tested.

## Next verification gates
1. Wait for and inspect CI checks on the latest PR head.
2. Run the ACL proposal against a disposable PostgreSQL fixture and execute its assertions.
3. Verify MFA enrollment and challenge redirects on mobile and desktop, including return-to behavior.
4. Run Storage API tests for AAL1 denial, AAL2 success, foreign-org denial, wrong-user path denial, and authorized cleanup.
5. Once migration-ledger recovery is complete, apply the exact ACL migration to staging and test a real authorized partner flow without inventing verified business data.
