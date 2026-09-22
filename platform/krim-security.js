/* =========================================================
   KRIM SECURITY SERVICE
   Permanent frontend security coordination layer

   IMPORTANT:
   Frontend security is NOT the final security boundary.
   Real authorization is enforced by Supabase Auth, RBAC,
   RLS, security-definer functions and Edge Functions.
   ========================================================= */

(function () {
    "use strict";


    /* -------------------------------------------------------
       DEPENDENCY CHECK
       ------------------------------------------------------- */

    function getAuth() {
        if (!window.KRIM_AUTH) {
            throw new Error(
                "KRIM: Authentication service is not initialized."
            );
        }

        return window.KRIM_AUTH;
    }


    function getApi() {
        if (!window.KRIM_API) {
            throw new Error(
                "KRIM: API service is not initialized."
            );
        }

        return window.KRIM_API;
    }


    /* -------------------------------------------------------
       SAFE ROUTE
       ------------------------------------------------------- */

    function safeRoute(path, fallback) {

        const candidate =
            path ||
            fallback ||
            window.KRIM_CONFIG.routes.public.home;

        try {
            return new URL(
                candidate,
                window.location.origin
            ).href;
        } catch (error) {
            return new URL(
                window.KRIM_CONFIG.routes.public.home,
                window.location.origin
            ).href;
        }
    }


    /* -------------------------------------------------------
       SESSION
       ------------------------------------------------------- */

    async function requireAuthentication(
        options
    ) {
        const config = options || {};

        const session =
            await getAuth().getSession();

        if (session) {
            return session;
        }

        const redirect =
            config.redirect ||
            window.KRIM_CONFIG.routes.auth.login;

        const currentUrl =
            window.location.href;

        const loginUrl =
            new URL(
                safeRoute(redirect),
                window.location.origin
            );

        if (config.preserveReturnUrl !== false) {
            loginUrl.searchParams.set(
                "returnTo",
                currentUrl
            );
        }

        window.location.replace(
            loginUrl.href
        );

        return null;
    }


    /* -------------------------------------------------------
       CURRENT USER
       ------------------------------------------------------- */

    async function requireUser(
        options
    ) {
        const session =
            await requireAuthentication(
                options
            );

        if (!session) {
            return null;
        }

        const user =
            await getAuth().getUser();

        if (!user) {
            const redirect =
                (options && options.redirect) ||
                window.KRIM_CONFIG.routes.auth.login;

            window.location.replace(
                safeRoute(redirect)
            );

            return null;
        }

        return user;
    }


    /* -------------------------------------------------------
       MFA / ASSURANCE LEVEL
       ------------------------------------------------------- */

    async function getMFAStatus() {
        return getAuth()
            .getAssuranceLevel();
    }


    async function requireMFA(
        options
    ) {
        const config = options || {};

        const assurance =
            await getMFAStatus();

        /*
         * Supabase returns:
         *
         * currentLevel
         * nextLevel
         *
         * AAL2 means the session has satisfied
         * multi-factor authentication.
         */

        if (
            assurance &&
            assurance.currentLevel === "aal2"
        ) {
            return assurance;
        }

        const redirect =
            config.redirect ||
            window.KRIM_CONFIG.routes.auth.mfa;

        const mfaUrl =
            new URL(
                safeRoute(redirect),
                window.location.origin
            );

        if (
            config.preserveReturnUrl !== false
        ) {
            mfaUrl.searchParams.set(
                "returnTo",
                window.location.href
            );
        }

        window.location.replace(
            mfaUrl.href
        );

        return assurance;
    }


    /* -------------------------------------------------------
       MFA FACTORS
       ------------------------------------------------------- */

    async function listMFAFactors() {
        return getAuth()
            .listMFAFactors();
    }


    /* -------------------------------------------------------
       ROLE ASSIGNMENTS
       ------------------------------------------------------- */

    async function getRoleAssignments(
        userId
    ) {

        const user =
            userId ||
            (
                await getAuth().getUser()
            )?.id;

        if (!user) {
            return [];
        }


        const rows =
            await getApi().select(
                "krim_user_role_assignments",
                "*",
                {
                    filters: [
                        {
                            column: "user_id",
                            operator: "eq",
                            value: user
                        }
                    ]
                }
            );


        return Array.isArray(rows)
            ? rows
            : [];
    }


    /* -------------------------------------------------------
       ROLE CHECK
       ------------------------------------------------------- */

    async function hasRole(
        roleCode,
        userId
    ) {

        if (!roleCode) {
            return false;
        }

        const assignments =
            await getRoleAssignments(
                userId
            );


        return assignments.some(
            function (assignment) {

                const assignedRole =
                    assignment.role_code ||
                    assignment.role ||
                    assignment.code;

                const active =
                    assignment.active !== false;

                return (
                    active &&
                    assignedRole === roleCode
                );
            }
        );
    }


    async function requireRole(
        roleCode,
        options
    ) {

        const config = options || {};

        const user =
            await requireUser(
                config
            );

        if (!user) {
            return null;
        }


        const allowed =
            await hasRole(
                roleCode,
                user.id
            );


        if (allowed) {
            return user;
        }


        if (config.onDenied) {
            config.onDenied({
                type: "role",
                role: roleCode,
                user: user
            });
        }


        if (config.redirect) {
            window.location.replace(
                safeRoute(
                    config.redirect,
                    window.KRIM_CONFIG.routes.public.home
                )
            );
        }


        throw new Error(
            "KRIM: Required role was not granted."
        );
    }


    /* -------------------------------------------------------
       PERMISSION CHECK
       ------------------------------------------------------- */

    async function hasPermission(
        permissionCode,
        userId
    ) {

        if (!permissionCode) {
            return false;
        }


        const assignments =
            await getRoleAssignments(
                userId
            );


        if (!assignments.length) {
            return false;
        }


        const activeRoles =
            assignments
                .filter(function (assignment) {
                    return assignment.active !== false;
                })
                .map(function (assignment) {
                    return (
                        assignment.role_code ||
                        assignment.role ||
                        assignment.code
                    );
                })
                .filter(Boolean);


        if (!activeRoles.length) {
            return false;
        }


        /*
         * Permission mappings are read through the
         * existing KRIM RBAC tables.
         *
         * RLS remains responsible for preventing
         * unauthorized database access.
         */

        const mappings =
            await getApi().select(
                "krim_role_permissions",
                "*",
                {
                    filters: [
                        {
                            column: "role_code",
                            operator: "in",
                            value: activeRoles
                        }
                    ]
                }
            );


        if (!Array.isArray(mappings)) {
            return false;
        }


        const permissionIds =
            mappings
                .filter(function (mapping) {
                    return mapping.active !== false;
                })
                .map(function (mapping) {
                    return (
                        mapping.permission_id ||
                        mapping.permission_code
                    );
                })
                .filter(Boolean);


        if (
            permissionIds.includes(
                permissionCode
            )
        ) {
            return true;
        }


        /*
         * If the mapping itself stores the permission
         * code, the check above is sufficient.
         *
         * Otherwise resolve through the permission
         * reference table.
         */

        if (!permissionIds.length) {
            return false;
        }


        const permissions =
            await getApi().select(
                "krim_security_permissions",
                "*",
                {
                    filters: [
                        {
                            column: "id",
                            operator: "in",
                            value: permissionIds
                        }
                    ]
                }
            );


        return permissions.some(
            function (permission) {

                const code =
                    permission.code ||
                    permission.permission_code;

                const active =
                    permission.active !== false;

                return (
                    active &&
                    code === permissionCode
                );
            }
        );
    }


    /* -------------------------------------------------------
       REQUIRE PERMISSION
       ------------------------------------------------------- */

    async function requirePermission(
        permissionCode,
        options
    ) {

        const config = options || {};

        const user =
            await requireUser(
                config
            );

        if (!user) {
            return null;
        }


        const allowed =
            await hasPermission(
                permissionCode,
                user.id
            );


        if (allowed) {
            return user;
        }


        if (config.onDenied) {
            config.onDenied({
                type: "permission",
                permission: permissionCode,
                user: user
            });
        }


        if (config.redirect) {
            window.location.replace(
                safeRoute(
                    config.redirect,
                    window.KRIM_CONFIG.routes.public.home
                )
            );
        }


        throw new Error(
            "KRIM: Required permission was not granted."
        );
    }


    /* -------------------------------------------------------
       SAFE REDIRECT
       ------------------------------------------------------- */

    function safeRedirect(
        target,
        fallback
    ) {

        const defaultTarget =
            fallback ||
            window.KRIM_CONFIG.routes.public.home;

        if (!target) {
            return safeRoute(
                defaultTarget
            );
        }


        try {

            const url =
                new URL(
                    target,
                    window.location.origin
                );


            /*
             * Only allow same-origin navigation.
             */

            if (
                url.origin !==
                window.location.origin
            ) {
                return safeRoute(
                    defaultTarget
                );
            }


            return url.href;

        } catch (error) {

            return safeRoute(
                defaultTarget
            );
        }
    }


    /* -------------------------------------------------------
       PROTECTED PAGE INITIALIZATION
       ------------------------------------------------------- */

    async function protectPage(
        options
    ) {

        const config = options || {};


        const user =
            await requireUser({
                redirect:
                    config.loginRedirect ||
                    window.KRIM_CONFIG.routes.auth.login,

                preserveReturnUrl:
                    config.preserveReturnUrl !== false
            });


        if (!user) {
            return null;
        }


        if (config.requireMFA === true) {

            await requireMFA({
                redirect:
                    config.mfaRedirect ||
                    window.KRIM_CONFIG.routes.auth.mfa,

                preserveReturnUrl:
                    config.preserveReturnUrl !== false
            });
        }


        if (config.role) {

            await requireRole(
                config.role,
                {
                    redirect:
                        config.deniedRedirect,

                    onDenied:
                        config.onDenied
                }
            );
        }


        if (config.permission) {

            await requirePermission(
                config.permission,
                {
                    redirect:
                        config.deniedRedirect,

                    onDenied:
                        config.onDenied
                }
            );
        }


        return user;
    }


    /* -------------------------------------------------------
       SENSITIVE PAGE CACHE CONTROL
       ------------------------------------------------------- */

    function disableSensitiveCaching() {

        /*
         * Browser-side cache hints only.
         *
         * Server/CDN headers remain the authoritative
         * mechanism for cache control.
         */

        try {

            const existing =
                document.querySelector(
                    'meta[http-equiv="Cache-Control"]'
                );

            if (!existing) {

                const meta =
                    document.createElement(
                        "meta"
                    );

                meta.httpEquiv =
                    "Cache-Control";

                meta.content =
                    "no-store, no-cache, must-revalidate";

                document.head.appendChild(
                    meta
                );
            }


            const pragma =
                document.querySelector(
                    'meta[http-equiv="Pragma"]'
                );

            if (!pragma) {

                const meta =
                    document.createElement(
                        "meta"
                    );

                meta.httpEquiv =
                    "Pragma";

                meta.content =
                    "no-cache";

                document.head.appendChild(
                    meta
                );
            }

        } catch (error) {

            console.warn(
                "KRIM: Could not apply browser cache hints.",
                error
            );
        }
    }


    /* -------------------------------------------------------
       PUBLIC SECURITY API
       ------------------------------------------------------- */

    window.KRIM_SECURITY = Object.freeze({

        requireAuthentication,

        requireUser,

        getMFAStatus,

        requireMFA,

        listMFAFactors,

        getRoleAssignments,

        hasRole,

        requireRole,

        hasPermission,

        requirePermission,

        safeRedirect,

        protectPage,

        disableSensitiveCaching

    });

})();
