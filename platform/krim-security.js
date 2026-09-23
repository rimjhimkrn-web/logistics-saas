/* =========================================================
   KRIM SECURITY SERVICE
   Permanent frontend security coordination layer

   IMPORTANT:
   Frontend security is NOT the final security boundary.
   Real authorization is enforced by Supabase Auth, RBAC,
   RLS, security-definer functions and Edge Functions.

   VERIFIED RBAC SCHEMA:
   krim_user_role_assignments.role_id
   -> krim_security_roles.id
   -> krim_role_permissions.role_id
   -> krim_role_permissions.permission_id
   -> krim_security_permissions.id
   ========================================================= */

(function () {
    "use strict";

    function getAuth() {
        if (!window.KRIM_AUTH) {
            throw new Error("KRIM: Authentication service is not initialized.");
        }
        return window.KRIM_AUTH;
    }

    function getApi() {
        if (!window.KRIM_API) {
            throw new Error("KRIM: API service is not initialized.");
        }
        return window.KRIM_API;
    }

    function getConfig() {
        if (!window.KRIM_CONFIG) {
            throw new Error("KRIM: Platform configuration is not initialized.");
        }
        return window.KRIM_CONFIG;
    }

    function safeRoute(path, fallback) {
        const candidate =
            path ||
            fallback ||
            getConfig().routes.public.home;

        try {
            return new URL(candidate, window.location.origin).href;
        } catch (error) {
            return new URL(
                getConfig().routes.public.home,
                window.location.origin
            ).href;
        }
    }

    async function requireAuthentication(options) {
        const config = options || {};
        const session = await getAuth().getSession();

        if (session) {
            return session;
        }

        const loginUrl = new URL(
            safeRoute(
                config.redirect ||
                getConfig().routes.auth.login
            ),
            window.location.origin
        );

        if (config.preserveReturnUrl !== false) {
            loginUrl.searchParams.set(
                "returnTo",
                window.location.href
            );
        }

        window.location.replace(loginUrl.href);
        return null;
    }

    async function requireUser(options) {
        const session = await requireAuthentication(options);

        if (!session) {
            return null;
        }

        const user = await getAuth().getUser();

        if (user) {
            return user;
        }

        window.location.replace(
            safeRoute(
                (options && options.redirect) ||
                getConfig().routes.auth.login
            )
        );

        return null;
    }

    async function getMFAStatus() {
        return getAuth().getAssuranceLevel();
    }

    async function requireMFA(options) {
        const config = options || {};
        const assurance = await getMFAStatus();

        if (
            assurance &&
            assurance.currentLevel === "aal2"
        ) {
            return assurance;
        }

        const mfaUrl = new URL(
            safeRoute(
                config.redirect ||
                getConfig().routes.auth.mfa
            ),
            window.location.origin
        );

        if (config.preserveReturnUrl !== false) {
            mfaUrl.searchParams.set(
                "returnTo",
                window.location.href
            );
        }

        window.location.replace(mfaUrl.href);
        return assurance;
    }

    async function listMFAFactors() {
        return getAuth().listMFAFactors();
    }

    async function getRoleAssignments(userId) {
        const user =
            userId ||
            (await getAuth().getUser())?.id;

        if (!user) {
            return [];
        }

        const rows = await getApi().select(
            "krim_user_role_assignments",
            "*",
            {
                filters: [
                    {
                        column: "user_id",
                        operator: "eq",
                        value: user
                    },
                    {
                        column: "is_active",
                        operator: "eq",
                        value: true
                    }
                ]
            }
        );

        return Array.isArray(rows) ? rows : [];
    }

    async function getRoleRecords(userId) {
        const assignments =
            await getRoleAssignments(userId);

        const roleIds = assignments
            .map(function (assignment) {
                return assignment.role_id;
            })
            .filter(function (id) {
                return id !== null &&
                       id !== undefined;
            });

        if (!roleIds.length) {
            return [];
        }

        const roles = await getApi().select(
            "krim_security_roles",
            "*",
            {
                filters: [
                    {
                        column: "id",
                        operator: "in",
                        value: roleIds
                    }
                ]
            }
        );

        return Array.isArray(roles) ? roles : [];
    }

    async function hasRole(roleCode, userId) {
        if (!roleCode) {
            return false;
        }

        const roles =
            await getRoleRecords(userId);

        return roles.some(function (role) {
            return role.role_code === roleCode;
        });
    }

    async function requireRole(roleCode, options) {
        const config = options || {};
        const user = await requireUser(config);

        if (!user) {
            return null;
        }

        const allowed =
            await hasRole(roleCode, user.id);

        if (allowed) {
            return user;
        }

        if (typeof config.onDenied === "function") {
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
                    getConfig().routes.public.home
                )
            );
        }

        throw new Error(
            "KRIM: Required role was not granted."
        );
    }

    async function hasPermission(
        permissionCode,
        userId
    ) {
        if (!permissionCode) {
            return false;
        }

        const roles =
            await getRoleRecords(userId);

        const roleIds = roles
            .map(function (role) {
                return role.id;
            })
            .filter(function (id) {
                return id !== null &&
                       id !== undefined;
            });

        if (!roleIds.length) {
            return false;
        }

        const mappings = await getApi().select(
            "krim_role_permissions",
            "*",
            {
                filters: [
                    {
                        column: "role_id",
                        operator: "in",
                        value: roleIds
                    },
                    {
                        column: "granted",
                        operator: "eq",
                        value: true
                    }
                ]
            }
        );

        if (
            !Array.isArray(mappings) ||
            !mappings.length
        ) {
            return false;
        }

        const permissionIds = mappings
            .map(function (mapping) {
                return mapping.permission_id;
            })
            .filter(function (id) {
                return id !== null &&
                       id !== undefined;
            });

        if (!permissionIds.length) {
            return false;
        }

        const permissions = await getApi().select(
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

        if (!Array.isArray(permissions)) {
            return false;
        }

        return permissions.some(function (permission) {
            return (
                permission.permission_code ===
                permissionCode
            );
        });
    }

    async function requirePermission(
        permissionCode,
        options
    ) {
        const config = options || {};
        const user = await requireUser(config);

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

        if (typeof config.onDenied === "function") {
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
                    getConfig().routes.public.home
                )
            );
        }

        throw new Error(
            "KRIM: Required permission was not granted."
        );
    }

    function safeRedirect(target, fallback) {
        const defaultTarget =
            fallback ||
            getConfig().routes.public.home;

        if (!target) {
            return safeRoute(defaultTarget);
        }

        try {
            const url = new URL(
                target,
                window.location.origin
            );

            if (
                url.origin !==
                window.location.origin
            ) {
                return safeRoute(defaultTarget);
            }

            return url.href;
        } catch (error) {
            return safeRoute(defaultTarget);
        }
    }

    async function protectPage(options) {
        const config = options || {};

        const user = await requireUser({
            redirect:
                config.loginRedirect ||
                getConfig().routes.auth.login,
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
                    getConfig().routes.auth.mfa,
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

    function disableSensitiveCaching() {
        try {
            if (!document.querySelector(
                'meta[http-equiv="Cache-Control"]'
            )) {
                const meta =
                    document.createElement("meta");

                meta.httpEquiv = "Cache-Control";
                meta.content =
                    "no-store, no-cache, must-revalidate";

                document.head.appendChild(meta);
            }

            if (!document.querySelector(
                'meta[http-equiv="Pragma"]'
            )) {
                const meta =
                    document.createElement("meta");

                meta.httpEquiv = "Pragma";
                meta.content = "no-cache";

                document.head.appendChild(meta);
            }
        } catch (error) {
            console.warn(
                "KRIM: Could not apply browser cache hints.",
                error
            );
        }
    }

    window.KRIM_SECURITY = Object.freeze({
        requireAuthentication,
        requireUser,
        getMFAStatus,
        requireMFA,
        listMFAFactors,
        getRoleAssignments,
        getRoleRecords,
        hasRole,
        requireRole,
        hasPermission,
        requirePermission,
        safeRedirect,
        protectPage,
        disableSensitiveCaching
    });

})();
