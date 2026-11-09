# KRIM Customer mobile app — preview 0.1.0

Expo + React Native Android/iOS foundation for the KRIM shipper/customer experience.

## Included
- Five-tab customer workspace: Home, Request, Track, Payments and Profile.
- Supabase email/password sign-in and password-reset request.
- Session persistence with Expo SecureStore.
- Shipment request form preview; it does not submit until a verified backend RPC contract is integrated.
- Honest empty states: no fabricated shipment status, quotes, routes, charges or payment balances.
- No service-role key or production secret in source.

## Configure
Copy `.env.example` to `.env` and set:
- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Never put a service-role key, database password, webhook secret or Razorpay secret in the app.

## Run
From this folder: `npm install`, then `npx expo start`. Install Expo Go on Android and scan the QR code. Run `npm run typecheck` for TypeScript validation.

## Release gates
Verify customer identity/org authorization, shipment creation RPC and RLS, quote retrieval, shipment tracking visibility, payment order creation and webhook-confirmed payment status before enabling any live action. Physical-device, accessibility, privacy and security tests are required before release. This is a development preview, not a production release.
