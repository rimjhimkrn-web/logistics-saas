# KRIM Driver mobile app — preview 0.1.0

Expo + React Native foundation for the driver/field-execution experience.

## Included
- Five-tab driver workspace: Today, Tasks, Proof, Safety and Profile.
- Supabase email/password sign-in and password-reset request.
- Session persistence with Expo SecureStore.
- Explicit pre-launch controls: no dispatch acceptance, route navigation, location tracking, proof-of-delivery upload or job completion actions are enabled.
- No fabricated assignments, addresses, customer data, earnings or delivery statuses.
- No service-role key or production secret in source.

## Configure
Copy `.env.example` to `.env` and set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Never place a service-role key or other server secret in the app.

## Run
From this folder run `npm install`, then `npx expo start`. Install Expo Go on Android and scan the QR code. Run `npm run typecheck` for TypeScript validation.

## Release gates
Before enabling driver operations, verify driver identity and employment/partner association, dispatch assignment authorization, location consent and retention, safety escalation, POD evidence handling, offline behavior and server-side shipment state transitions. Test on physical devices. This is a development preview, not a production release.
