/* =========================================================
   KRIM GLOBAL AUTHENTICATION SERVICE
   Permanent Authentication Layer
   ========================================================= */

(function () {

    "use strict";

    const KRIM_AUTH = {

        async getSession() {

            if (!window.KRIM_SUPABASE) {
                throw new Error(
                    "KRIM Supabase client is not initialized."
                );
            }

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth.getSession();

            if (error) {
                throw error;
            }

            return data.session || null;
        },


        async getUser() {

            if (!window.KRIM_SUPABASE) {
                throw new Error(
                    "KRIM Supabase client is not initialized."
                );
            }

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth.getUser();

            if (error) {
                return null;
            }

            return data.user || null;
        },


        async isAuthenticated() {

            const session =
                await this.getSession();

            return Boolean(session);
        },


        async signIn(email, password) {

            if (!email || !password) {
                throw new Error(
                    "Email and password are required."
                );
            }

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .signInWithPassword({
                    email: email.trim(),
                    password: password
                });

            if (error) {
                throw error;
            }

            return data;
        },


        async signOut() {

            const {
                error
            } = await window.KRIM_SUPABASE.auth.signOut();

            if (error) {
                throw error;
            }
        },


        async resetPassword(email) {

            if (!email) {
                throw new Error(
                    "Email address is required."
                );
            }

            const redirectUrl =
                new URL(
                    KRIM_CONFIG.routes.auth.resetPassword,
                    window.location.href
                ).href;

            const {
                error
            } = await window.KRIM_SUPABASE.auth
                .resetPasswordForEmail(
                    email.trim(),
                    {
                        redirectTo: redirectUrl
                    }
                );

            if (error) {
                throw error;
            }
        },


        async getAssuranceLevel() {

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .getAuthenticatorAssuranceLevel();

            if (error) {
                throw error;
            }

            return data;
        },


        async listMFAFactors() {

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .mfa.listFactors();

            if (error) {
                throw error;
            }

            return data;
        },


        async challengeMFA(factorId) {

            if (!factorId) {
                throw new Error(
                    "MFA factor ID is required."
                );
            }

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .mfa.challenge({
                    factorId: factorId
                });

            if (error) {
                throw error;
            }

            return data;
        },


        async verifyMFA(factorId, challengeId, code) {

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

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .mfa.verify({
                    factorId: factorId,
                    challengeId: challengeId,
                    code: String(code).trim()
                });

            if (error) {
                throw error;
            }

            return data;
        },


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

            const {
                data,
                error
            } = await window.KRIM_SUPABASE.auth
                .mfa.challengeAndVerify({
                    factorId: factorId,
                    code: String(code).trim()
                });

            if (error) {
                throw error;
            }

            return data;
        },


        async onAuthStateChange(callback) {

            if (
                typeof callback !== "function"
            ) {
                throw new Error(
                    "Auth callback must be a function."
                );
            }

            return window.KRIM_SUPABASE.auth
                .onAuthStateChange(callback);
        }

    };


    window.KRIM_AUTH = KRIM_AUTH;

})();
