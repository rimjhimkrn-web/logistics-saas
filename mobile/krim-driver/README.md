# KRIM Driver mobile app — 0.2.0 internal preview

Expo SDK 54 / React Native driver workspace connected to the KRIM Supabase production project through a publishable key and the signed-in driver's session.

## Operational capabilities
- Secure email/password sign-in and password reset; session persistence uses Expo SecureStore.
- Driver profile, assignment, trip-event and private proof-of-delivery workflows.
- Assignment-scoped GPS sharing for verified drivers, only after the server confirms an in-transit assignment.
- Explicit in-app consent before location permissions are requested.
- Android background-location implementation through the OS location foreground service and persistent notification when permission is granted; currently paused by a source-level launch gate pending retention, deletion and legal approval.
- Foreground-only fallback when background permission is not granted.
- GPS uploads require an authenticated session, verified driver profile, active organization membership, active partner shipment assignment and an active server-recorded consent session.
- Driver stop control records a server-side stop event; assignment state changes away from in-transit stop local tracking on the next refresh.
- Location updates with accuracy worse than 250 metres are rejected; server applies a 15-second minimum interval and stationary-position filtering.
- No service-role key or production secret is bundled in the app.

## Location privacy and safety
Tracking is OFF by default and currently held behind both app-side and server-side launch gates. It must not be enabled for commercial shipments until KRIM approves a category-specific retention schedule, deletion/legal-hold process and final location notice. When enabled, it is started only by the assigned driver for a verified, in-transit shipment after a clear consent notice. The app requests foreground permission first. On Android 13+, it requests notification permission before background permission so the persistent tracking notice can be visible; if notification or background access is declined, the app falls back to foreground-only tracking while the app remains open. Android displays an ongoing location-sharing foreground-service notification when background tracking is active.

Drivers can stop sharing at any time. KRIM must not use this feature for employee surveillance outside assigned work, emergency response, or safety-critical navigation. Device shutdown, force-stop, battery restrictions, poor GPS signal, offline periods and OS/vendor behavior can interrupt location updates. Customer views must show the server timestamp and freshness state; never imply a live position when data is stale.

The app's background-location permissions require platform review and disclosures before any public Play Store release. An internal APK is for controlled testing only. Complete the Google Play background-location declaration, privacy policy and Data safety disclosures, and Apple privacy/Always-location review before public distribution. Verify the applicable India DPDP and other corridor privacy requirements with qualified counsel before commercial rollout.

## Configure and run
Copy `.env.example` to `.env` and set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Never put a service-role key or webhook secret in the app.

Run `npm install`, then `npm run typecheck` and `npx expo export --platform android`. A development/internal build is required to test native background location; Expo Go on Android does not support the location foreground/background service.

## Current release gate (15 November 2026)

The public shipment-tracking endpoint now applies the same server-side GPS legal-approval gate as the driver session and GPS upload endpoints. When GPS is not approved and enabled, customers continue to receive shipment milestones but do not receive GPS positions, including previously recorded positions. Do not open the launch gate until the exact notice, retention/deletion/legal-hold process and legal approval version are approved, and physical-device tests pass.

## Required release verification
- Test on physical Android devices from multiple manufacturers, including Android 13/14+, with precise and approximate permission, background permission allowed/denied, battery saver, screen locked, app swiped away, force-stop, network loss and recovery.
- Verify start/stop consent rows, GPS event freshness, server authorization and customer visibility end-to-end using a real authorized test driver and shipment.
- Test iOS Always permission and background behavior before enabling iOS distribution.
- Validate data retention, deletion, access requests, incident handling and public privacy disclosures with counsel.
- Do not advertise guaranteed continuous tracking; location services are best-effort and device/OS/network dependent.

This is an internal operational preview, not a public production release.

## Automated validation
The repository workflow `.github/workflows/krim-partner-mobile.yml` validates the KRIM Partner, Customer and Driver Expo apps, then builds installable internal Android debug APKs for KRIM Partner, KRIM Customer and KRIM Driver on pushes to the mobile app paths. Only KRIM Driver receives background-location and location foreground-service permissions; customer and partner apps are checked to exclude them. It checks Expo SDK package compatibility, TypeScript, native Android configuration, the Android JavaScript bundle and the merged manifest's background-location and foreground-service permissions.

## Internal Android debug build

The repository workflow `KRIM mobile app validation` (`.github/workflows/krim-partner-mobile.yml`) validates all three apps with committed lockfiles (`npm ci`) and builds separate installable debug APKs for controlled device testing. Driver-only background location permissions are verified in the driver manifest; customer and partner manifests are checked for least-privilege exclusion. The debug APK uses Android's debug signing key and is not a Play Store or EAS release. If a previously installed EAS-signed KRIM Driver preview cannot be updated because of a signing mismatch, do not uninstall it until any local test data is backed up; the debug build may need a separate package ID or a clean test device.

GPS remains disabled by app-side and server-side launch gates. The server now archives the exact server-controlled consent notice, its SHA-256 hash and locale with each future accepted tracking session; the upload endpoint checks that archived copy before accepting a location point. The current notice is explicitly a draft and the separate consent-approval gate is false. Do not use the debug APK for commercial shipments until qualified counsel approves the notice and retention/deletion/legal-hold schedule, the approval gate is deliberately changed, and physical-device end-to-end testing passes.
