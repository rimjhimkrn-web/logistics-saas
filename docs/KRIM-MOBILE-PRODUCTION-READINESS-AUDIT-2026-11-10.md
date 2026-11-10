# KRIM Mobile Apps — Production Readiness Audit

Date: 2026-11-10
Repository: rimjhimkrn-web/logistics-saas
Scope: KRIM Customer, KRIM Partner, KRIM Driver
Audit type: Read-only source/configuration inspection. No production database changes and no app source changes were made.

## Executive status

The three Android preview APKs have been built and installed by the owner. The owner confirmed that all three apps launch to their login/workspace entry screens. This is an installation milestone only; it is not evidence of production readiness, backend end-to-end correctness, store approval, or global operating coverage.

Current release posture: **internal preview / not ready for public app-store release**.

## Confirmed configuration

| Item | Customer | Partner | Driver |
|---|---|---|---|
| Expo SDK | 54 | 54 | 54 |
| React Native | 0.81.4 | 0.81.4 | 0.81.4 |
| Android application ID | com.krimlogistics.customer | com.krimlogistics.partner | com.krimlogistics.driver |
| iOS bundle ID | com.krimlogistics.customer | com.krimlogistics.partner | com.krimlogistics.driver |
| Expo project ID | 20a6e037-2c44-4386-935b-50b116296eda | b747dd8c-2ebc-4f4e-b76e-8d24ec81f3e7 | b7c30b66-5d6c-45f7-b311-99ff6e37eb01 |
| Current app version | 0.1.0 | 0.1.0 | 0.1.0 |
| Android versionCode | 2 | 2 | 2 |
| EAS preview distribution | Internal APK | Internal APK | Internal APK |

The preview profile in each app's eas.json explicitly sets internal distribution and Android APK output. The production profile exists and has autoIncrement enabled, but the current installation builds were preview APKs, not store-submission releases.

## Findings and release blockers

### P0 — Production configuration and identity
1. Verify that the production EAS environment contains the correct `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` for all three projects. Preview values were configured previously; production environment values have not been verified in this audit.
2. Keep service-role keys, database passwords, secret API keys, and schema-export passphrases out of mobile builds. Only the publishable client key belongs in the app.
3. Verify EAS production Android signing, package ownership, iOS credentials, and production build provenance before release.
4. Verify that each production app has an explicit release version strategy, runtime/update compatibility policy, and a tested rollback path.

### P0 — Functional and security acceptance
1. Complete synthetic-account authentication tests for all three roles.
2. Verify session persistence, logout, password reset, token refresh, and account recovery.
3. Verify organization membership and row-level security isolation using separate synthetic Customer, Partner, and Driver users.
4. Test no-membership, no-profile, no-assignment, offline, timeout, and backend-error states.
5. Keep commercial and operational writes disabled until their server-side authorization and end-to-end tests pass.

### P1 — Globalization and accessibility
1. The inspected app entry points and workspace screens use hard-coded English strings. No translation resource structure or localization framework was identified in the inspected app source/configuration.
2. No completed locale strategy is present in the inspected app configuration. Add translation keys/resources and locale negotiation before adding large amounts of further UI copy.
3. Design for translated text expansion, plural rules, locale-aware dates/numbers, country-aware phone formats, currencies, units, time zones, and Arabic/right-to-left layout.
4. Add accessibility labels, screen-reader checks, scalable text, contrast checks, and minimum tap-target verification across the three apps.
5. Global architecture must not be confused with live country coverage: activate a country/route only when partner, legal, customs, payment, tax, and service capability requirements are verified.

### P1 — Build reproducibility and release engineering
1. Each app package currently declares dependencies using version ranges. No app-local lockfile appeared in the inspected app directory listings. Introduce and commit reproducible lockfiles and use deterministic CI installs.
2. The Android preview workflow generates PNG icon assets from SVG during CI. Ensure the production build path uses the same deterministic icon-generation step, or commit validated PNG assets as build inputs.
3. Add separate, protected preview and production build workflows. Production builds must not silently use placeholder environment values.
4. Add automated checks for package IDs, app names, icon files, version codes, environment presence, dependency audit, TypeScript, and Android/iOS Expo config validation.
5. Verify the minimum/target Android API level against current Google Play submission requirements at the time of submission. Do not assume SDK 54 alone guarantees store compliance.
6. iOS identifiers are configured, but no iOS build or TestFlight validation has been evidenced in this audit.

### P1 — Store and legal readiness
1. Prepare accurate store listings, screenshots, app descriptions, support contact, privacy disclosures, data-safety answers, age/content ratings, and account deletion/support flows.
2. Confirm the KRIM brand/name/logo can be used in target markets and does not infringe an existing mark. Conduct a formal trademark clearance before making claims of exclusive ownership.
3. Review privacy policy, terms, data retention, consent, cross-border transfers, processor/vendor disclosures, incident response, and country-specific obligations with qualified counsel.
4. Do not represent KRIM as licensed, certified, insured, or available in a country unless that status is documented and current.
5. App-store developer enrollment and publishing are separate from building APKs. Do not incur registration or legal spend until the release gates and budget are approved.

## Current app capability posture

The inspected workspace source describes read-oriented operational workspaces. The source itself states that important operations are gated:
- Customer: shipment/quote visibility and tracking; shipment creation, quote acceptance, and payments are not enabled in the current app release.
- Partner: organization/capability/opportunity visibility; quote submission and assignment acceptance are gated.
- Driver: assigned-work and trip-history visibility; assignment acceptance, trip writes, live location, and POD upload are disabled.

These gates are appropriate until server-side controls and full end-to-end workflows are validated. Do not test with live shipments, customer data, driver location, identity documents, or payment credentials.

## Recommended implementation order

1. Finish the source/config audit and correct stale mobile QA documentation.
2. Verify production EAS environment configuration without exposing secret values.
3. Add shared localization foundations and accessibility standards across the three apps.
4. Establish reproducible dependency/build pipelines and separate production AAB / iOS release profiles.
5. Run isolated synthetic-user authentication and role-isolation tests.
6. Implement and test each operational workflow against approved backend contracts.
7. Complete legal, privacy, brand, and store listing review.
8. Produce signed production candidates, test them, then submit to Google Play and Apple App Store.

## Explicit non-claims

This audit does not certify legal compliance, trademark ownership, global availability, app-store approval, full backend correctness, or production security. It does not change the production Supabase database, enable live operational actions, or publish any app.
