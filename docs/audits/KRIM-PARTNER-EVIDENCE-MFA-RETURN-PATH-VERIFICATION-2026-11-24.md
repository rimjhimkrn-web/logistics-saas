# Partner evidence MFA return-path and ACL preflight verification — 2026-11-24

## Additional UX hardening
The first MFA remediation redirected users to the Partner Workspace after enrollment/challenge and required them to reopen the evidence page. This was improved:

- Capacity and service-area pages now pass their own current URL as the post-MFA return destination, with query string and fragment removed.
- `auth/mfa-enroll.html` and `auth/mfa-challenge.html` now allow only the two exact partner evidence page paths (with and without the GitHub Pages `/logistics-saas` base path) in addition to their existing allowlisted destinations.
- Both auth pages retain same-origin checks; no arbitrary external URL is accepted.
- The MFA gate still runs before the first Storage upload.

## Read-only verification
- Fetched all four updated files from the PR branch and confirmed the two evidence pages build a sanitized same-page return URL.
- Confirmed both MFA auth pages include the exact partner evidence route allowlist.
- Confirmed both upload handlers call their MFA gate before reaching the upload loop.
- Confirmed the capacity RPC preflight markers on staging: exact overload exists, SECURITY DEFINER is true, explicit empty search_path is configured, and auth.uid(), permission, compliance, Storage object ownership, pending_review and unavailable markers are present.
- Re-read live ACLs: production anon=false/authenticated=true/service_role=true; staging anon=false/authenticated=false/service_role=true. This confirms the staging mismatch is unchanged and the proposed ACL repair is still required.

## Not verified
- No local PostgreSQL server, psql or Docker runtime is available in this execution environment. The proposed migration and assertion SQL have therefore not been executed against a disposable PostgreSQL instance.
- No browser automation, MFA enrollment/challenge round-trip or real Storage upload was run.
- GitHub reports no commit status checks and no workflow runs for the current PR head at the time of review.

## Safety decision
No production or staging database privileges were changed. Do not apply the ACL proposal until the migration-history recovery gate is cleared and the migration is executed and verified in a disposable PostgreSQL environment. Keep PR #245 draft.
