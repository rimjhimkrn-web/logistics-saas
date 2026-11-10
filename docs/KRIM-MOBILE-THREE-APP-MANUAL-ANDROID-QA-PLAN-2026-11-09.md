# KRIM Mobile Apps — Manual Android QA Plan

Last updated: 2026-11-10
Apps: KRIM Customer, KRIM Partner, KRIM Driver
Status: **Initial install and launch checks passed on the owner's Android phone. Authentication, role-isolation, and operational workflow testing remain NOT completed.**

## Current build facts
- Customer package: `com.krimlogistics.customer`
- Partner package: `com.krimlogistics.partner`
- Driver package: `com.krimlogistics.driver`
- Expo SDK: 54
- React Native: 0.81.4
- Each app uses Supabase Auth and Expo SecureStore.
- Each app expects two public build-time environment variables:
  - `EXPO_PUBLIC_SUPABASE_URL`
  - `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- Preview values for these two public variables were configured in the Expo Preview environment for all three projects. Production EAS environment values have not yet been verified.
- EAS project IDs are configured in each app's app.json; an Expo access token is stored as the protected GitHub Actions secret `EXPO_TOKEN`.
- The owner reports all three internal preview APKs were downloaded, installed, and opened successfully to their login/workspace entry screen.
- The recent builds were internal Android APKs, not production AABs and not Play Store releases.
- Never put a database password, service-role key, secret API key, or schema-export passphrase in a mobile app or any `EXPO_PUBLIC_*` variable.

## Recorded manual device checks

| App | APK installed | App opened to entry/login screen | Authentication tested | Role isolation tested |
|---|---|---|---|---|
| KRIM Customer | Yes | Yes | Not yet | Not yet |
| KRIM Partner | Yes | Yes | Not yet | Not yet |
| KRIM Driver | Yes | Yes | Not yet | Not yet |

The owner confirmed the KRIM Partner app opens, KRIM Driver opens, and KRIM Customer opens. The Partner icon was visually described and confirmed as the configured KRIM icon. Customer and Driver icon appearance has not been independently confirmed in this record.

## Safe manual testing order

### A. Install and launch
Initial installation and launch are recorded as passed. Remaining checks:
1. Confirm the correct app name and icon for each app.
2. Check small-screen layout and keyboard behavior.
3. Force-close and reopen each app.
4. Confirm one app does not display another app's session.
5. Test offline startup and recoverable network error handling.

### B. Authentication
Use separate synthetic test accounts for Customer, Partner, and Driver. Do not share one account across roles.
1. Enter an invalid email/password and confirm a safe error appears.
2. Enter the valid synthetic test account and sign in.
3. Force-close and reopen; confirm the session persists securely.
4. Sign out; confirm the login screen returns.
5. Try password reset with a test mailbox and confirm the neutral response.
6. Confirm no password, access token, or secret is displayed in UI or logs.

### C. Customer app
1. Sign in with a synthetic customer test user.
2. Confirm only active organizations belonging to that user appear.
3. If no organization is assigned, confirm the app shows the no-membership state.
4. Switch between any authorized organizations.
5. Check Home, Shipments, Quotes, Track, and Account tabs.
6. Open a synthetic shipment and check its tracking timeline.
7. Refresh data and sign out.
8. Negative authorization test: use a second customer account and confirm the first account's organization, shipments, quotes, and tracking are not visible.

Important: the current customer workspace is read-oriented. Shipment creation, quote acceptance, and payment are not enabled in the current app release.

### D. Partner app
1. Sign in with a synthetic partner test user.
2. Confirm only partner/carrier/forwarder organizations for which the user has active membership appear.
3. Test the no-partner-organization state.
4. Check Overview, Opportunities, Shipments, Earnings, and Profile.
5. Confirm verification/compliance/capability status is displayed accurately.
6. Confirm unverified or non-compliant partners are not shown as commercially ready.
7. Refresh and sign out.
8. Negative authorization test: a second partner must not see the first partner's capabilities, quotes, or assignments.

Important: opportunity visibility depends on backend row-level security and organization selection. Quote submission and assignment acceptance are gated; this is not yet an operational partner execution app.

### E. Driver app
1. Sign in with a synthetic driver test user.
2. Confirm only that user's driver profile and assignments appear.
3. Test the no-driver-profile and no-assignment states.
4. Check Today, Tasks, Proof, Safety, and Profile.
5. Open a synthetic assignment and inspect pickup/delivery details and recorded events.
6. Confirm another driver cannot see this driver's assignments or trip events.
7. Confirm no background location permission or tracking is active.
8. Sign out.

Important: assignment acceptance, trip-event writes, live location, and POD upload are disabled in the current app release. Do not use real shipments or driver data for this test.

## Cross-app negative tests
- Sign out of one role and sign in with another role; confirm old role data is not retained.
- Use a user with no active organization membership; confirm no organization data appears.
- Try to access a shipment, quote, opportunity, or assignment belonging to a different synthetic organization; access must be denied or return no rows.
- Disable network and reopen each app; confirm a clear recoverable error, not a crash or stale sensitive data.
- Re-enable network and refresh.
- Verify screen-reader labels and tap targets for login and bottom navigation.

## Test data rules
- Use synthetic test users, organizations, shipments, quotes, and assignments in isolated staging only.
- Do not create test rows in production.
- Do not use real identity documents, bank details, customer addresses, or live payment credentials.
- Never enable live dispatch, booking, POD, or payments solely to make a manual test pass.

## Build profiles
Each app has EAS profiles for development, preview, and production:
- `preview`: internal distribution and Android APK output.
- `production`: production profile with auto-increment enabled. A production Android AAB and iOS release have not yet been verified.
- Preview environment variables were configured. Production environment values and production signing credentials must be checked before production builds.

The GitHub workflow `.github/workflows/krim-android-internal-apk.yml` builds the selected app's preview APK. It is not the production store-release workflow.

## Release gate
All three apps must pass authentication/session tests, role-isolation tests, screen navigation tests, and error/recovery tests in isolated staging. Operational write features require separate API authorization and end-to-end tests before they can be enabled. Production configuration, reproducible dependencies, localization, accessibility, store metadata, and legal/privacy reviews are additional release gates.
