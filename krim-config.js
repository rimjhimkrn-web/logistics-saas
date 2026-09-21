/* KRIM GLOBAL CONFIGURATION */

const KRIM_CONFIG = {
    platform: {
            name: "KRIM Logistics",
                    environment: "production",
                            defaultMarket: "IN",
                                    defaultCurrency: "INR",
                                            defaultTimezone: "Asia/Kolkata"
                                                },

                                                    supabase: {
                                                            url: "https://ebltviniygljwwseplph.supabase.co",
                                                                    publishableKey: "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"
                                                                        },

                                                                            routes: {
                                                                                    home: "home.html",
                                                                                            customerLogin: "customer-login.html",
                                                                                                    partnerLogin: "partner-login.html",
                                                                                                            adminLogin: "admin-login.html",
                                                                                                                    customerWorkspace: "customer-workspace.html",
                                                                                                                            partnerWorkspace: "partner-workspace.html",
                                                                                                                                    operationsWorkspace: "operations-workspace.html"
                                                                                                                                        }
                                                                                                                                        };