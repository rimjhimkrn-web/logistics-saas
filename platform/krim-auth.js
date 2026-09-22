/* =========================================================
   KRIM AUTHENTICATION SERVICE
   Permanent shared authentication layer
   ========================================================= */

(function () {
    "use strict";

    function getClient() {
        if (!window.KRIM_SUPABASE) {
            throw new Error(
                "KRIM: Supabase client is not initialized."
            );
        }

        return window.KRIM_SUPABASE;
    }


    const KRIM_AUTH = {

        /* ---------------------------------------------------
           SESSION
           --------------------------------------------------- */

        async getSession() {
            const { data, error } =
                await getClient().auth.getSession();

            if (error) {
                throw error;
            }

            return data.session || null;
        },


        /* ---------------------------------------------------
           CURRENT USER
           --------------------------------------------------- */

        async getUser() {
            const { data, error } =
                await getClient().auth.getUser();

            if (error) {
                return null;
            }

            return data.user || null;
        },


        /* ---------------------------------------------------
           AUTHENTICATION STATUS
           --------------------------------------------------- */

        async isAuthenticated() {
            const session = await this.getSession();

            return Boolean(session);
        },


        /* ---------------------------------------------------
           SIGN IN
           --------------------------------------------------- */

        async signIn(email, password) {

            if (!email) {
                throw new Error(
                    "Email address is required."
                );
            }

            if (!password) {
                throw new Error(
                    "Password is required."
                );
            }

            const { data, error } =
                await getClient().auth.signInWithPassword({
                    email: String(email).trim(),
                    password: password
                });

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           SIGN OUT
           --------------------------------------------------- */

        async signOut() {

            const { error } =
                await getClient().auth.signOut();

            if (error) {
                throw error;
            }

            return true;
        },


        /* ---------------------------------------------------
           PASSWORD RESET
           --------------------------------------------------- */

        async resetPassword(email) {

            if (!email) {
                throw new Error(
                    "Email address is required."
                );
            }

            const resetRoute =
                window.KRIM_CONFIG.routes.auth.resetPassword;

            const redirectUrl =
                new URL(
                    resetRoute,
                    window.location.origin
                ).href;

            const { error } =
                await getClient().auth.resetPasswordForEmail(
                    String(email).trim(),
                    {
                        redirectTo: redirectUrl
                    }
                );

            if (error) {
                throw error;
            }

            return true;
        },


        /* ---------------------------------------------------
           UPDATE PASSWORD
           --------------------------------------------------- */

        async updatePassword(newPassword) {

            if (!newPassword) {
                throw new Error(
                    "New password is required."
                );
            }

            const { data, error } =
                await getClient().auth.updateUser({
                    password: newPassword
                });

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           AUTHENTICATOR ASSURANCE LEVEL
           --------------------------------------------------- */

        async getAssuranceLevel() {

            const { data, error } =
                await getClient()
                    .auth
                    .getAuthenticatorAssuranceLevel();

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           MFA FACTORS
           --------------------------------------------------- */

        async listMFAFactors() {

            const { data, error } =
                await getClient()
                    .auth
                    .mfa
                    .listFactors();

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           MFA CHALLENGE
           --------------------------------------------------- */

        async challengeMFA(factorId) {

            if (!factorId) {
                throw new Error(
                    "MFA factor ID is required."
                );
            }

            const { data, error } =
                await getClient()
                    .auth
                    .mfa
                    .challenge({
                        factorId: factorId
                    });

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           MFA VERIFY
           --------------------------------------------------- */

        async verifyMFA(
            factorId,
            challengeId,
            code
        ) {

            if (!factorId) {
                throw new Error(
                    "MFA factor ID is required."
                );
            }

            if (!challengeId) {
                throw new Error(
                    "MFA challenge ID is required."
                );
            }

            if (!code) {
                throw new Error(
                    "MFA verification code is required."
                );
            }

            const { data, error } =
                await getClient()
                    .auth
                    .mfa
                    .verify({
                        factorId: factorId,
                        challengeId: challengeId,
                        code: String(code).trim()
                    });

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           MFA CHALLENGE + VERIFY
           --------------------------------------------------- */

        async challengeAndVerifyMFA(
            factorId,
            code
        ) {

            if (!factorId) {
                throw new Error(
                    "MFA factor ID is required."
                );
            }

            if (!code) {
                throw new Error(
                    "MFA verification code is required."
                );
            }

            const { data, error } =
                await getClient()
                    .auth
                    .mfa
                    .challengeAndVerify({
                        factorId: factorId,
                        code: String(code).trim()
                    });

            if (error) {
                throw error;
            }

            return data;
        },


        /* ---------------------------------------------------
           AUTH STATE LISTENER
           --------------------------------------------------- */

        onAuthStateChange(callback) {

            if (typeof callback !== "function") {
                throw new Error(
                    "Auth callback must be a function."
                );
            }

            return getClient()
                .auth
                .onAuthStateChange(callback);
        }

    };


    /*
     * -------------------------------------------------------
     * PUBLIC KRIM AUTH API
     * -------------------------------------------------------
     */

    window.KRIM_AUTH = Object.freeze(
        KRIM_AUTH
    );

})();
