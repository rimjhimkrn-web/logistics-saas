# KRIM Supabase Security Advisor Triage — 2026-11-28

## Scope
Read-only review of KRIM staging project `qrpcivhdxobiaofppbkl` and production project `ebltviniygljwwseplph`. No database, Auth, payment, route, or booking settings were changed.

## Advisor snapshot
| Finding | Staging | Production | Triage |
|---|---:|---:|---|
| RLS enabled, no policies | 31 | 29 | Review schema exposure and intended access before creating policies |
| Authenticated can execute SECURITY DEFINER functions | 55 | 151 | Review each function's authorization checks and intended caller set |
| Leaked-password protection disabled | 1 | 1 | Auth configuration improvement; requires owner-approved change and verification |

## RLS finding classification
A read-only catalog query checked each flagged table for RLS status and table privileges.

- All flagged tables had RLS enabled.
- For every flagged table returned by the query, `anon` and `authenticated` had no direct SELECT or INSERT table privileges.
- The flagged set includes private-schema internal tables and public-schema tables. The public-schema tables should still be assessed for Data API exposure, grants inherited through other roles, views, and function-mediated access.
- The linter's “no policy” notice is not by itself proof of public data exposure. Do not add blanket policies merely to silence it.

## Required safe remediation sequence
1. Inventory exposed schemas and effective privileges, including inherited role grants and views.
2. For each SECURITY DEFINER function, inspect owner, search_path, EXECUTE grants, caller authorization, tenant/org checks, and data returned or mutated.
3. Revoke or change function privileges only after proving the intended application call path remains functional and tests cover unauthorized cross-tenant attempts.
4. Enable leaked-password protection only through an approved Auth configuration change, then verify sign-in and password reset behavior.
5. Run Supabase Security Advisor again and record before/after results.

## Launch safeguards
- Do not enable shipment booking while the atomic shipment/corridor contract remains unverified.
- Do not activate a market, corridor, partner capability, or driver dispatch privilege without real evidence and independent approval.
- Keep freight collection and settlement disabled under the current referral/coordination launch model.
- Do not run production DDL/RPC changes until the repository-to-production migration crosswalk is reconciled.

## Platform inventory
The connected Replit account returned zero editable apps. No duplicate Replit application was created. The existing GitHub repository and Supabase projects remain the source of truth.
