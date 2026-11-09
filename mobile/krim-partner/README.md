# KRIM Partner mobile app — preview 0.1.0

Expo + React Native Android/iOS foundation for the first KRIM mobile application.

## Included
- Five-tab partner app shell: Overview, Opportunities, Shipments, Earnings and Profile.
- Supabase email/password sign-in and password-reset request.
- Session persistence using Expo SecureStore (chunked to respect per-item storage limits).
- Existing KRIM partner onboarding hand-off.
- Pre-launch controls: no live loads, quotes, assignments, payouts or commercial actions.
- Honest empty states; no fabricated routes, rates, shipments, balances or verification status.
- No service-role key or production secret in source.

## Configure
Set these Expo public environment variables in a local .env file or build environment:
- EXPO_PUBLIC_SUPABASE_URL
- EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY

Use the existing KRIM Supabase project URL and public publishable key from the existing web configuration. Do not copy a service-role key, database password, webhook secret or Razorpay secret into this app.

The first pass integrates authentication only. Partner organization membership, verification, capabilities, opportunities, quotations, assignments, documents and finance data must be connected only after the actual production schema/RPC/Edge Function contracts and RLS rules are verified. Frontend role labels are never authorization.

## Run
Install Node.js LTS, then from this folder run npm install and npx expo start. Install Expo Go on an Android phone and scan the QR code. Use npm run typecheck for TypeScript validation.

## Release gates
Before Play Store or App Store launch: configure EAS and signing; verify package/bundle identifier ownership; test real-device layouts and session expiry; verify backend role/org authorization and RLS negative tests; add partner data contracts; complete offline, accessibility, privacy and legal review; then run internal testing. This branch is a development preview, not a production release.
