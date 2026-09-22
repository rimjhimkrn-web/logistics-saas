/* =========================================================
   KRIM GLOBAL SECURITY SERVICE
   Permanent Frontend Security Layer
   ========================================================= */

(function () {

    "use strict";

    const KRIM_SECURITY = {

        /* -------------------------------------------------
           AUTHENTICATION CHECK
           ------------------------------------------------- */

        async requireAuthentication(
            redirect = null
        ) {

            if (!window.KRIM_AUTH) {
                throw new Error(
                    "KRIM authentication service is not initialized."
                );
            }

            const session =
                await window.KRIM_AUTH.getSession();

            if (!session) {

                const target =
                    redirect ||
                    KRIM_CONFIG.routes.auth.login;

                window.location.href =
                    new URL(
                        target,
                        window.location.href
                    ).href;

                return null;
            }

            return session;
        },


        /* -------------------------------------------------
           CURRENT USER
           ------------------------------------------------- */

        async requireUser(
            redirect = null
        ) {

            if (!window.KRIM_AUTH) {
                throw new Error(
                    "KRIM authentication service is not initialized."
                );
            }

            const user =
                await window.KRIM_AUTH.getUser();

            if (!user) {

                const target =
                    redirect ||
                    KRIM_CONFIG.routes.auth.login;

                window.location.href =
                    new URL(
                        target,
                        window.location.href
                    ).href;

                return null;
            }

            return user;
        },


        /* -------------------------------------------------
           MFA / ASSURANCE LEVEL
           ------------------------------------------------- */

        async getAssuranceLevel() {

            if (!window.KRIM_AUTH) {
                throw new Error(
                    "KRIM authentication service is not initialized."
                );
            }

            return window.KRIM_AUTH
                .getAssuranceLevel();
        },


        async requiresMFA() {

            const assurance =
                await this.getAssuranceLevel();

            return (
                assurance &&
                assurance.nextLevel === "aal2" &&
                assurance.currentLevel !== "aal2"
            );
        },


        async requireMFA(
            redirect = null
        ) {

            const assurance =
                await this.getAssuranceLevel();

            if (!assurance) {
                throw new Error(
                    "Unable to determine authentication assurance level."
                );
            }

            if (
                assurance.currentLevel ===
                "aal2"
            ) {
                return true;
            }

            if (
                assurance.nextLevel ===
                "aal2"
            ) {

                const target =
                    redirect ||
                    KRIM_CONFIG.routes.auth.mfa;

                window.location.href =
                    new URL(
                        target,
                        window.location.href
                    ).href;

                return false;
            }

            return true;
        },


        /* -------------------------------------------------
           ROLE / PERMISSION HELPERS
           ------------------------------------------------- */

        async getRoleAssignments(
            userId = null
        ) {

            const user =
                await this.requireUser();

            const targetUserId =
                userId ||
                user.id;

            return window.KRIM_API.select(
                "krim_user_role_assignments",
                "*",
                {
                    filters: [
                        {
                            operator: "eq",
                            column: "user_id",
                            value: targetUserId
                        }
                    ]
                }
            );
        },


        async hasRole(
            roleCode
        ) {

            if (!roleCode) {
                return false;
            }

            const assignments =
                await this.getRoleAssignments();

            return assignments.some(
                assignment =>
                    assignment.role_code ===
                        roleCode &&
                    assignment.active !== false
            );
        },


        async hasPermission(
            permissionCode
        ) {

            if (!permissionCode) {
                return false;
            }

            const user =
                await this.requireUser();

            const assignments =
                await this.getRoleAssignments(
                    user.id
                );

            if (!assignments.length) {
                return false;
            }

            const roleCodes =
                assignments
                    .filter(
                        assignment =>
                            assignment.active !== false
                    )
                    .map(
                        assignment =>
                            assignment.role_code
                    )
                    .filter(Boolean);

            if (!roleCodes.length) {
                return false;
            }

            const permissions =
                await window.KRIM_API.select(
                    "krim_role_permissions",
                    "*"
                );

            const securityPermissions =
                await window.KRIM_API.select(
                    "krim_security_permissions",
                    "*",
                    {
                        filters: [
                            {
                                operator: "eq",
                                column: "code",
                                value: permissionCode
                            }
                        ]
                    }
                );

            if (
                !securityPermissions.length
            ) {
                return false;
            }

            const permissionId =
                securityPermissions[0].id;

            return permissions.some(
                mapping =>
                    roleCodes.includes(
                        mapping.role_code
                    ) &&
                    mapping.permission_id ===
                        permissionId &&
                    mapping.active !== false
            );
        },


        /* -------------------------------------------------
           ROLE REQUIREMENT
           ------------------------------------------------- */

        async requireRole(
            roleCode,
            redirect = null
        ) {

            const allowed =
                await this.hasRole(
                    roleCode
                );

            if (allowed) {
                return true;
            }

            const target =
                redirect ||
                KRIM_CONFIG.routes.workspace.customer;

            window.location.href =
                new URL(
                    target,
                    window.location.href
                ).href;

            return false;
        },


        /* -------------------------------------------------
           PERMISSION REQUIREMENT
           ------------------------------------------------- */

        async requirePermission(
            permissionCode,
            redirect = null
        ) {

            const allowed =
                await this.hasPermission(
                    permissionCode
                );

            if (allowed) {
                return true;
            }

            const target =
                redirect ||
                KRIM_CONFIG.routes.workspace.customer;

            window.location.href =
                new URL(
                    target,
                    window.location.href
                ).href;

            return false;
        },


        /* -------------------------------------------------
           SAFE REDIRECT
           ------------------------------------------------- */

        safeRedirect(
            path
        ) {

            if (!path) {
                return false;
            }

            const url =
                new URL(
                    path,
                    window.location.href
                );

            if (
                url.protocol !==
                window.location.protocol
            ) {
                return false;
            }

            window.location.href =
                url.href;

            return true;
        },


        /* -------------------------------------------------
           PROTECTED PAGE INITIALIZATION
           ------------------------------------------------- */

        async protectPage({
            requireAuth = true,
            requireMFA = false,
            role = null,
            permission = null
        } = {}) {

            if (requireAuth) {

                const session =
                    await this.requireAuthentication();

                if (!session) {
                    return false;
                }
            }

            if (requireMFA) {

                const mfaPassed =
                    await this.requireMFA();

                if (!mfaPassed) {
                    return false;
                }
            }

            if (role) {

                const roleAllowed =
                    await this.requireRole(
                        role
                    );

                if (!roleAllowed) {
                    return false;
                }
            }

            if (permission) {

                const permissionAllowed =
                    await this.requirePermission(
                        permission
                    );

                if (!permissionAllowed) {
                    return false;
                }
            }

            return true;
        },


        /* -------------------------------------------------
           NO-STORE FOR SENSITIVE UI
           ------------------------------------------------- */

        disableSensitiveCaching() {

            const meta =
                document.createElement("meta");

            meta.httpEquiv =
                "Cache-Control";

            meta.content =
                "no-store, no-cache, must-revalidate, max-age=0";

            document.head.appendChild(
                meta
            );

            const pragma =
                document.createElement("meta");

            pragma.httpEquiv =
                "Pragma";

            pragma.content =
                "no-cache";

            document.head.appendChild(
                pragma
            );

            const expires =
                document.createElement("meta");

            expires.httpEquiv =
                "Expires";

            expires.content =
                "0";

            document.head.appendChild(
                expires
            );
        },


        /* -------------------------------------------------
           INITIALIZATION
           ------------------------------------------------- */

        init() {

            if (
                KRIM_CONFIG.security
                    .requireAuthenticatedSessionForProtectedRoutes
            ) {

                this.disableSensitiveCaching();
            }

            return true;
        }

    };


    window.KRIM_SECURITY =
        KRIM_SECURITY;


    if (
        document.readyState ===
        "loading"
    ) {

        document.addEventListener(
            "DOMContentLoaded",
            () => KRIM_SECURITY.init(),
            {
                once: true
            }
        );

    } else {

        KRIM_SECURITY.init();
    }

})();
