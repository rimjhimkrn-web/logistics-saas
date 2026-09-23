(function () {
  "use strict";

  function getClient() {
    if (!window.KRIM_SUPABASE) {
      throw new Error("KRIM Supabase client is not ready.");
    }

    return window.KRIM_SUPABASE;
  }


  async function getSession() {
    const client = getClient();

    const { data, error } =
      await client.auth.getSession();

    if (error) {
      throw error;
    }

    return data.session || null;
  }


  async function getUser() {
    const client = getClient();

    const { data, error } =
      await client.auth.getUser();

    if (error) {
      throw error;
    }

    return data.user || null;
  }


  async function isAuthenticated() {
    const session = await getSession();

    return !!session;
  }


  async function signIn(email, password) {
    const client = getClient();

    const { data, error } =
      await client.auth.signInWithPassword({
        email,
        password
      });

    if (error) {
      throw error;
    }

    return data;
  }


  async function signOut() {
    const client = getClient();

    const { error } =
      await client.auth.signOut();

    if (error) {
      throw error;
    }

    return true;
  }


  async function resetPassword(email, redirectTo) {
    const client = getClient();

    const { error } =
      await client.auth.resetPasswordForEmail(
        email,
        {
          redirectTo
        }
      );

    if (error) {
      throw error;
    }

    return true;
  }


  async function updatePassword(password) {
    const client = getClient();

    const { data, error } =
      await client.auth.updateUser({
        password
      });

    if (error) {
      throw error;
    }

    return data;
  }


  /*
   * ----------------------------------------------------
   * MFA / AUTHENTICATOR ASSURANCE
   * ----------------------------------------------------
   *
   * IMPORTANT:
   * Supabase exposes these methods through:
   *
   * client.auth.mfa
   *
   * NOT:
   *
   * client.auth.getAuthenticatorAssuranceLevel()
   */


  async function getAssuranceLevel() {
    const client = getClient();

    if (
      !client.auth ||
      !client.auth.mfa ||
      typeof client.auth.mfa
        .getAuthenticatorAssuranceLevel !== "function"
    ) {
      throw new Error(
        "Supabase MFA API is unavailable. Please verify the Supabase JavaScript client is loaded correctly."
      );
    }


    const { data, error } =
      await client.auth.mfa
        .getAuthenticatorAssuranceLevel();


    if (error) {
      throw error;
    }


    return data;
  }


  async function listMFAFactors() {
    const client = getClient();

    if (
      !client.auth ||
      !client.auth.mfa ||
      typeof client.auth.mfa.listFactors !== "function"
    ) {
      throw new Error(
        "Supabase MFA factor API is unavailable."
      );
    }


    const { data, error } =
      await client.auth.mfa.listFactors();


    if (error) {
      throw error;
    }


    return data;
  }


  async function challengeMFA(factorId) {
    const client = getClient();

    if (
      !client.auth ||
      !client.auth.mfa ||
      typeof client.auth.mfa.challenge !== "function"
    ) {
      throw new Error(
        "Supabase MFA challenge API is unavailable."
      );
    }


    const { data, error } =
      await client.auth.mfa.challenge({
        factorId
      });


    if (error) {
      throw error;
    }


    return data;
  }


  async function verifyMFA(
    factorId,
    challengeId,
    code
  ) {
    const client = getClient();

    if (
      !client.auth ||
      !client.auth.mfa ||
      typeof client.auth.mfa.verify !== "function"
    ) {
      throw new Error(
        "Supabase MFA verification API is unavailable."
      );
    }


    const { data, error } =
      await client.auth.mfa.verify({
        factorId,
        challengeId,
        code
      });


    if (error) {
      throw error;
    }


    return data;
  }


  async function challengeAndVerifyMFA(
    factorId,
    code
  ) {
    const client = getClient();

    if (
      !client.auth ||
      !client.auth.mfa ||
      typeof client.auth.mfa.challengeAndVerify !== "function"
    ) {
      throw new Error(
        "Supabase MFA challenge-and-verify API is unavailable."
      );
    }


    const { data, error } =
      await client.auth.mfa.challengeAndVerify({
        factorId,
        code
      });


    if (error) {
      throw error;
    }


    return data;
  }


  async function getMFAFactors() {
    return listMFAFactors();
  }


  function onAuthStateChange(callback) {
    const client = getClient();

    return client.auth.onAuthStateChange(
      callback
    );
  }


  /*
   * ----------------------------------------------------
   * PUBLIC KRIM AUTH SERVICE
   * ----------------------------------------------------
   */

  window.KRIM_AUTH = Object.freeze({

    getSession,
    getUser,
    isAuthenticated,

    signIn,
    signOut,

    resetPassword,
    updatePassword,

    getAssuranceLevel,

    listMFAFactors,
    getMFAFactors,

    challengeMFA,
    verifyMFA,
    challengeAndVerifyMFA,

    onAuthStateChange

  });

})();
