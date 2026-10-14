# KRIM Frontend Integration Contract

This is the required standard for every new KRIM web page. A page is not considered connected or launch-ready merely because its UI exists.

## Hosting and routes
- Current GitHub Pages project base: `/logistics-saas/`.
- Internal links, redirects, manifests, and local assets must work beneath that base path.
- New pages must build internal URLs with `window.krimPath('auth/login.html')` (or the relevant repo-relative path), rather than hard-coding `/logistics-saas/` or assuming domain root.
- Do not hard-code paths that assume the domain root. Verify links from both the public landing page and the nested page where they are used.
- The repository root `index.html` is the entry point and forwards to `public/index.html`.

## Shared Supabase client
- Load the Supabase JS v2 SDK first.
- Load `/logistics-saas/config.js` immediately after the SDK.
- Reuse `window.KRIM_SUPABASE`; do not create a separate client on every new page.
- The publishable key may be used in browser code; never place service-role keys, database passwords, Razorpay secrets, OpenAI keys, or Gemini keys in HTML/JavaScript.
- All user data must be authorized by Supabase Auth, RLS, and server-side RPC/Edge Function checks.

## Required page lifecycle
1. Define the page's purpose, user role, and authorized organization scope.
2. Check the authenticated session before loading protected data.
3. Resolve the current user's organization membership from the database; never use a demo organization or another user's latest record as a fallback.
4. Use RLS-protected reads and vetted RPCs/Edge Functions for writes.
5. Treat browser-calculated prices and status changes as untrusted. Financial amounts and payment states must be determined server-side.
6. Render loading, empty, success, and error states; avoid injecting untrusted database values through `innerHTML`.
7. Use the canonical KRIM route conventions and link to related pages with validated record IDs.
8. Add audit events and idempotency to sensitive or retryable operations where supported.
9. Test authorized access, cross-organization denial, expired sessions, network failure, duplicate submission, and mobile layout.
10. Mark the page launch-ready only after real end-to-end tests pass.

## Current rollout status
The shared configuration and route normalization are being rolled out incrementally. This contract does not claim that all existing pages, payment workflows, data policies, or global operations have passed end-to-end testing.
