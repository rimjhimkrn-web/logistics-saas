// js/auth-core.js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Global KRIM OS Configuration
export const SUPABASE_URL = "https://your-supabase-project.supabase.co";
export const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'pkce'
  }
});

// Centralized Navigation Matrix
export const AUTH_ROUTES = {
  SIGN_IN: 'login.html',
  SIGN_UP: 'signup.html',
  VERIFY_EMAIL: 'verify-email.html',
  VERIFY_PHONE: 'verify-phone.html',
  FORGOT_PASSWORD: 'forgot-password.html',
  RESET_PASSWORD: 'reset-password.html',
  MFA_ENROLL: 'mfa-enroll.html',
  MFA_CHALLENGE: 'mfa-challenge.html',
  RECOVERY: 'recovery.html',
  INVITATION: 'invitation.html',
  DISABLED: 'disabled.html',
  DASHBOARD: 'dashboard.html'
};

// Global Session Health & RBAC Guard
export async function requireAuth(minimumAal = 'aal1') {
  const { data: { session }, error } = await supabase.auth.getSession();

  if (error || !session) {
    window.location.href = AUTH_ROUTES.SIGN_IN;
    return null;
  }

  // Check MFA Authenticator Assurance Level
  const { data: mfaData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (minimumAal === 'aal2' && mfaData?.currentLevel !== 'aal2') {
    window.location.href = AUTH_ROUTES.MFA_CHALLENGE;
    return null;
  }

  return session;
}

// Global Environment Switcher Injector for GitHub Pages Testing
export function renderTestSwitcher() {
  const switcher = document.createElement('div');
  switcher.id = 'krim-test-switcher';
  switcher.innerHTML = `
    <style>
      #krim-test-switcher { position: fixed; bottom: 16px; right: 16px; z-index: 9999; font-family: monospace; }
      .kts-btn { background: rgba(6, 182, 212, 0.15); border: 1px solid rgba(6, 182, 212, 0.4); color: #22d3ee; padding: 8px 12px; border-radius: 12px; font-weight: bold; cursor: pointer; font-size: 11px; backdrop-filter: blur(8px); }
      .kts-menu { display: none; position: absolute; bottom: 40px; right: 0; width: 260px; background: #0f172a; border: 1px solid rgba(255,255,255,0.15); border-radius: 16px; p: 12px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
      .kts-menu.active { display: block; }
      .kts-menu a { display: block; padding: 8px 10px; margin: 4px 0; background: rgba(255,255,255,0.05); color: #cbd5e1; text-decoration: none; border-radius: 8px; font-size: 11px; }
      .kts-menu a:hover { background: rgba(6, 182, 212, 0.2); color: #fff; }
    </style>
    <button class="kts-btn" onclick="document.getElementById('kts-nav').classList.toggle('active')">🧪 Test Pages Switcher</button>
    <div id="kts-nav" class="kts-menu">
      <div style="font-weight:bold; color:#fff; padding:6px 10px; border-bottom:1px solid rgba(255,255,255,0.1); margin-bottom:6px;">Auth Testing Matrix</div>
      <a href="login.html">1. Login Gateway</a>
      <a href="signup.html">2. Registration</a>
      <a href="verify-email.html">3. Email OTP Verify</a>
      <a href="verify-phone.html">4. Phone / Driver SMS Auth</a>
      <a href="forgot-password.html">5. Request Password Reset</a>
      <a href="reset-password.html">6. Update Password</a>
      <a href="mfa-enroll.html">7. MFA Setup & Backup Keys</a>
      <a href="mfa-challenge.html">8. MFA TOTP Challenge</a>
      <a href="recovery.html">9. Emergency Recovery</a>
      <a href="invitation.html">10. Org Invitation</a>
      <a href="disabled.html">11. Account Restricted</a>
    </div>
  `;
  document.body.appendChild(switcher);
}
