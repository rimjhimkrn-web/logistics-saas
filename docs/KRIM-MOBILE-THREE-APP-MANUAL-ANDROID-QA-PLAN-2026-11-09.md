# KRIM Mobile Apps — Manual Android QA Plan

Date: 2026-11-09
Apps: KRIM Customer, KRIM Partner, KRIM Driver
Status: Source validation has passed in GitHub Actions; manual device testing has NOT yet been performed.

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
- Do not put a database password, service-role key, secret API key, or schema-export passphrase in a mobile app or any `EXPO_PUBLIC_*` variable.
- `eas.json` already defines internal `preview` and `development` profiles, but EAS project linking and cloud build credentials still need to be configured.

## Safe manual testing order

### A. Install and launch
For each app:
1. Install its internal preview APK on an Android test phone.
2. Open the app and confirm the correct KRIM app name and login screen.
3. Rotate is not supported (portrait only); check small-screen layout and keyboard behavior.
4. Force-close and reopen the app.
5. Confirm it does not crash or display another app's session.

### B. Authentication
Use separate test accounts for Customer, Partner, and Driver. Do not share a single account across roles.
1. Enter an invalid email/password and confirm a safe error appears.
2. Enter the valid test account and sign in.
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
6. Open a shipment and check tracking timeline.
7. Refresh data and sign out.
8. Negative authorization test: use a second customer account and confirm the first account's organization, shipments, quotes, and tracking are not visible.

Important: the current customer workspace is read-only. Shipment creation, quote acceptance, and payment are deliberately not enabled in this app build.

### D. Partner app
1. Sign in with a synthetic partner test user.
2. Confirm only partner/carrier/forwarder organizations for which the user has active membership appear.
3. Test the no-partner-organization state.
4. Check Overview, Opportunities, Shipments, Earnings, and Profile.
5. Confirm verification/compliance/capability status is displayed accurately.
6. Confirm unverified or non-compliant partners are not shown as commercially ready.
7. Refresh and sign out.
8. Negative authorization test: a second partner must not see the first partner's capabilities, quotes, or assignments.

Important: opportunity visibility depends on the backend's row-level security and the workspace's current organization-selection behavior. Quote submission and assignment acceptance are deliberately gated; this build is not an operational partner execution app yet.

### E. Driver app
1. Sign in with a synthetic driver test user.
2. Confirm only that user's driver profile and assignments appear.
3. Test the no-driver-profile and no-assignment states.
4. Check Today, Tasks, Proof, Safety, and Profile.
5. Open an assignment and inspect pickup/delivery details and recorded events.
6. Confirm another driver cannot see this driver's assignments or trip events.
7. Confirm no background location permission or tracking is active.
8. Sign out.

Important: assignment acceptance, trip-event writes, live location, and POD upload are deliberately disabled in this build. Do not use real shipments or driver data for this test.

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

## How to produce Android APKs
The repository's `eas.json` preview profile is configured for internal distribution. Before builds:
1. Create/sign in to an Expo account.
2. Link each app directory to its own EAS project using EAS CLI.
3. Configure the two public Supabase environment variables in the EAS project environment.
4. Add an Expo access token as a protected GitHub Actions secret named `EXPO_TOKEN` only if using GitHub Actions to start cloud builds.
5. Run the EAS Android preview build for each app and install the resulting internal APK on the test phone.

No EAS project IDs, Expo token, APK, or AAB have been configured/generated as of this document. Do not claim device testing or release readiness until the APKs have been installed and the test cases above have been recorded.

## Release gate
All three apps must pass the login/session tests, role isolation tests, screen navigation tests, and error/recovery tests in staging. Operational write features require separate API authorization and end-to-end tests before they can be enabled.
