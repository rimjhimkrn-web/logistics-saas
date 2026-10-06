/* ==========================================================================
   KRIM LOGISTICS OS — MULTI-FACTOR AUTHENTICATION (MFA) CORE ENGINE
   ========================================================================== */

const KrimMFA = {
  /**
   * Generates TOTP Enrollment payload via Supabase Auth
   */
  async enroll() {
    if (!window.KrimBackend || !window.KrimBackend.client) {
      throw new Error("Backend driver unavailable.");
    }
    
    const { data, error } = await window.KrimBackend.client.auth.mfa.enroll({
      factorType: 'totp',
      issuer: 'KRIM LOGISTICS OS'
    });

    if (error) throw error;
    return {
      factorId: data.id,
      qrCodeUrl: data.totp.qr_code,
      secret: data.totp.secret,
      uri: data.totp.uri
    };
  },

  /**
   * Verifies enrollment challenge code to activate MFA on user account
   */
  async verifyEnrollment(factorId, challengeCode) {
    const { client } = window.KrimBackend;
    
    const { data: challenge, error: challengeError } = await client.auth.mfa.challenge({ factorId });
    if (challengeError) throw challengeError;

    const { data: verify, error: verifyError } = await client.auth.mfa.verify({
      factorId,
      challengeId: challenge.id,
      code: challengeCode
    });

    if (verifyError) throw verifyError;
    return verify;
  },

  /**
   * Challenges an existing MFA factor during login flow
   */
  async challengeAndVerify(factorId, code) {
    const { client } = window.KrimBackend;

    const { data: challenge, error: challengeError } = await client.auth.mfa.challenge({ factorId });
    if (challengeError) throw challengeError;

    const { data: verify, error: verifyError } = await client.auth.mfa.verify({
      factorId,
      challengeId: challenge.id,
      code: code
    });

    if (verifyError) throw verifyError;
    return verify;
  },

  /**
   * Unenrolls / disables MFA factor
   */
  async unenroll(factorId) {
    const { client } = window.KrimBackend;
    const { data, error } = await client.auth.mfa.unenroll({ factorId });
    if (error) throw error;
    return data;
  }
};

window.KrimMFA = KrimMFA;
