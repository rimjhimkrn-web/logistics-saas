# KRIM FRONTEND FOUNDATION — BATCH 1

Status: IMPLEMENTATION ARTIFACT — NOT YET INTEGRATED

Purpose:
This batch introduces the canonical browser-side KRIM platform facade.

It is intentionally separate from the existing legacy platform layer until the
repository integration step is completed and verified.

Required integration order:
1. platform/krim-config.js
2. platform/krim-supabase.js
3. platform/krim-auth.js
4. platform/krim-api.js
5. core/localization/catalog.js
6. config/markets.js
7. platform/krim-platform.js
8. page-specific controller

Do not delete the legacy frontend layer until all dependent pages have been
migrated and regression-tested.

Acceptance gate:
- JavaScript syntax validation passes.
- Canonical config is available.
- Supabase client initializes.
- Auth facade is available.
- API facade is available.
- Existing public-page compatibility is verified.
- GitHub Pages pathing is verified.
- Mobile navigation is verified.
- Existing backend is unchanged.

This file is documentation only and is not a claim of completed integration.
