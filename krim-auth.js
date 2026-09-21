/* KRIM AUTHENTICATION FOUNDATION */

const KRIM_AUTH = {

    async getSession() {
            const response = await fetch(
                        KRIM_CONFIG.supabase.url + "/auth/v1/session",
                                    {
                                                    method: "GET",
                                                                    headers: {
                                                                                        "apikey": KRIM_CONFIG.supabase.publishableKey
                                                                                                        }
                                                                                                                    }
                                                                                                                            );

                                                                                                                                    if (!response.ok) {
                                                                                                                                                return null;
                                                                                                                                                        }

                                                                                                                                                                const data = await response.json();

                                                                                                                                                                        return data;
                                                                                                                                                                            },


                                                                                                                                                                                async getUser() {
                                                                                                                                                                                        const session = await this.getSession();

                                                                                                                                                                                                if (!session || !session.user) {
                                                                                                                                                                                                            return null;
                                                                                                                                                                                                                    }

                                                                                                                                                                                                                            return session.user;
                                                                                                                                                                                                                                },


                                                                                                                                                                                                                                    async isAuthenticated() {
                                                                                                                                                                                                                                            const user = await this.getUser();

                                                                                                                                                                                                                                                    return user !== null;
                                                                                                                                                                                                                                                        },


                                                                                                                                                                                                                                                            async requireAuthentication(loginPage) {
                                                                                                                                                                                                                                                                    const authenticated = await this.isAuthenticated();

                                                                                                                                                                                                                                                                            if (!authenticated) {
                                                                                                                                                                                                                                                                                        window.location.href = loginPage;
                                                                                                                                                                                                                                                                                                    return false;
                                                                                                                                                                                                                                                                                                            }

                                                                                                                                                                                                                                                                                                                    return true;
                                                                                                                                                                                                                                                                                                                        },


                                                                                                                                                                                                                                                                                                                            async logout() {
                                                                                                                                                                                                                                                                                                                                    await fetch(
                                                                                                                                                                                                                                                                                                                                                KRIM_CONFIG.supabase.url + "/auth/v1/logout",
                                                                                                                                                                                                                                                                                                                                                            {
                                                                                                                                                                                                                                                                                                                                                                            method: "POST",
                                                                                                                                                                                                                                                                                                                                                                                            headers: {
                                                                                                                                                                                                                                                                                                                                                                                                                "apikey": KRIM_CONFIG.supabase.publishableKey
                                                                                                                                                                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                                                                                                                                                                                    );

                                                                                                                                                                                                                                                                                                                                                                                                                                                            window.location.href = KRIM_CONFIG.routes.home;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                                                                                                                                                                                                                };