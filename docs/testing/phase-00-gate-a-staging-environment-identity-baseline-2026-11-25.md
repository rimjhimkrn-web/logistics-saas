# Phase 00 — Gate A Staging environment identity and deployment baseline

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Production Supabase project:** `ebltviniygljwwseplph`  
**Staging Supabase project:** `qrpcivhdxobiaofppbkl`  
**Method:** Read-only Supabase project metadata, migration history, GitHub branch metadata and deployment workflow/config source inspection. No deployment, database write, Auth change, DNS change, or provider action.

## Executive decision

**Gate A: PARTIAL PASS for Supabase project identity; BLOCKED for deployed Staging website identity.**

The two Supabase projects are distinct, healthy and identifiable by exact project reference, API URL, organization and region. The QA source maps the candidate `krim-staging.pages.dev` hostname to the Staging project and fails closed on unknown hosts.

However, the repository's production deployment workflow deploys GitHub Pages from `main`; it does not establish a Cloudflare Pages deployment for `krim-staging.pages.dev`. The candidate Staging origin could not be fetched by the web audit runtime. Therefore there is still no evidence tying a reachable deployed Staging website to a specific commit and the Staging Supabase project. **Do not create synthetic users or run authenticated browser/API tests yet.**

## 1. Supabase project identity — verified

| Attribute | Production | Staging |
|---|---|---|
| Project name | `logistics-saas` | `KRIM Logistics Staging` |
| Project ref | `ebltviniygljwwseplph` | `qrpcivhdxobiaofppbkl` |
| API URL | `https://ebltviniygljwwseplph.supabase.co` | `https://qrpcivhdxobiaofppbkl.supabase.co` |
| Organization ID | `mwvzahnqzveoapjggsug` | `mwvzahnqzveoapjggsug` |
| Region | `ap-northeast-1` | `ap-south-1` |
| Project status | `ACTIVE_HEALTHY` | `ACTIVE_HEALTHY` |
| PostgreSQL | `17.6.1.165` | `17.11.0.018` |
| Created | `2026-08-26T10:21:47Z` | `2026-11-07T14:43:16Z` |

**Result:** PASS for project separation and metadata identity. Both projects are in the same Supabase organization, but they have different refs, API hosts and regions. The region/version difference is not itself a defect; it must be included in parity testing.

## 2. Migration lineage — critical parity blocker reconfirmed

Live migration history returned:
- Production: **561** migration records; latest version `20261124071550` (`krim_report_operational_exception`).
- Staging: **34** migration records; latest version `20261123044931` (`refine_admin_driver_licence_expiry_rpc_security`).

This is a **527-record count difference**, not a schema diff. Migration names and versions show that Staging has a later-starting, selective migration history rather than the full Production history. It is not safe to assume that applying all missing Production migrations in order will be correct: there may be baseline, branch-specific, duplicate-version, manually-applied or data dependencies.

No migration was applied and no schema/data copy/reset was attempted.

**Required:** obtain complete ordered migration manifests for both environments; classify each Staging-only and Production-only migration; compare live schema objects (extensions, tables/columns, indexes, constraints, triggers, functions, grants, RLS policies, Storage policies and reference data); produce a reviewed forward-only reconciliation plan. Do not reset Staging or blindly replay 527 migrations.

## 3. GitHub source and branch identity — verified

GitHub branch metadata at audit time:
- `main`: `72d75a18f985ceb09e468839435ee95700e11e46` (commit timestamp `2026-11-25T05:35:04Z`).
- `qa/phase-00-baseline-2026-11-25`: `b28c8e8251297ba1923b1de2c5d7fd327e91eb6b` (commit timestamp `2026-11-25T09:07:30Z`).

Both branch protection metadata responses report `protected: false`. QA branch is ahead for audit documentation and must not be mistaken for the deployed Production commit.

The inspected `.github/workflows/deploy-krim-pages.yml` on `main`:
- deploys on pushes to `main` or manual workflow dispatch;
- builds the site and publishes through GitHub Pages actions;
- contains no Cloudflare Pages deployment step;
- does not deploy the QA branch automatically.

The QA `config.js`:
- maps `rimjhimkrn-web.github.io` to Production ref `ebltviniygljwwseplph`;
- maps `krim-staging.pages.dev` and its subdomains to Staging ref `qrpcivhdxobiaofppbkl`;
- maps localhost to Staging;
- blocks unknown hostnames before client initialization;
- sets `KRIM_AUTH_DISABLED = false` and enables persistent PKCE Auth.

This is QA-branch source evidence, not proof that this exact config is deployed at either origin. The main-branch deployed config and actual browser project identity still need verification.

## 4. Website origin and commit — NOT VERIFIED

The candidate `https://krim-staging.pages.dev/` could not be opened by the web audit runtime (internal fetch error). This is inconclusive: it does not prove that DNS or the website is down.

The public GitHub Pages URL was also not fetched successfully by the audit web runtime. The configured GitHub Actions workflow is strong repository evidence of the intended Pages deployment path, but a successful live deployment and deployed commit SHA were not independently established in this pass.

Cloudflare dashboard deployment/domain ownership, DNS, TLS certificate, HTTP status, redirects, deployed asset hashes and the exact commit serving the candidate Staging origin were not accessible/verified.

## 5. Gate A checklist

| Check | Result | Evidence |
|---|---|---|
| Production Supabase project identity | PASS | Exact ref, API URL, region and healthy status |
| Staging Supabase project identity | PASS | Exact ref, API URL, region and healthy status |
| Projects are distinct | PASS | Different project refs, API hosts and regions |
| QA source host-to-project mapping | PASS (source only) | Explicit allowlist and mapping in QA `config.js` |
| Unknown-host fail-closed behavior | PASS (source only) | Throws before client creation |
| Main deployment workflow identified | PASS | GitHub Pages workflow deploys from `main` |
| Candidate Cloudflare Pages deployment established by repository | BLOCKED | No Cloudflare deployment step/config evidenced |
| Candidate Staging DNS/TLS/HTTP and deployed commit | NOT VERIFIED | Audit fetch inconclusive; Cloudflare deployment not accessible |
| Live Production origin and deployed commit | NOT VERIFIED | Audit fetch inconclusive |
| Main deployed `config.js` points to Production | NOT VERIFIED | QA branch config inspected; main config not proven |
| Staging Auth Site URL/redirect allowlist | NOT VERIFIED | No Auth URL settings changed or independently read |
| Safe synthetic-test boundary | BLOCKED | Staging origin/commit and schema parity unresolved |

## 6. Gate A conclusion and next actions

**Gate A is not closed.** Supabase project identity is verified, but the web deployment-to-project binding is not.

The next required evidence is the actual Staging deployment record from the hosting dashboard, showing:
1. hosting provider/project and production deployment URL;
2. deployment status and deployed Git commit SHA;
3. custom/default domain mapping for the candidate hostname;
4. DNS and TLS status;
5. confirmation that the deployed site's runtime config resolves to `qrpcivhdxobiaofppbkl`, not Production.

Then independently fetch the deployed root and a harmless static config asset, verify HTTPS/redirects and record response headers and asset hashes. Only after this should the Staging Auth URL configuration be reviewed, and no settings should be saved without explicit approval.

After origin binding, proceed to Gate B: detailed schema/migration parity reconciliation. Synthetic identities remain prohibited until Gates A–C and test-isolation controls are accepted.

## Safety statement

Read-only project metadata, migration history and GitHub source/branch metadata were inspected. No SQL write, migration, schema change, Auth setting, secret, Storage policy, DNS record, hosting setting, deployment, merge, synthetic identity or provider request was created or modified. No real notification/payment was triggered.

**Disposition: Gate A PARTIAL PASS / BLOCKED. Phase 00 remains IN PROGRESS.**
