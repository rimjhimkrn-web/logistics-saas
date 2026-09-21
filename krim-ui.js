/* KRIM UI FOUNDATION */

const KRIM_UI = {

    show(element) {
            if (element) {
                        element.style.display = "";
                                }
                                    },


                                        hide(element) {
                                                if (element) {
                                                            element.style.display = "none";
                                                                    }
                                                                        },


                                                                            setText(element, text) {
                                                                                    if (element) {
                                                                                                element.textContent = text;
                                                                                                        }
                                                                                                            },


                                                                                                                showLoading(element, message = "Loading...") {
                                                                                                                        if (element) {
                                                                                                                                    element.textContent = message;
                                                                                                                                                element.setAttribute("aria-busy", "true");
                                                                                                                                                        }
                                                                                                                                                            },


                                                                                                                                                                hideLoading(element) {
                                                                                                                                                                        if (element) {
                                                                                                                                                                                    element.removeAttribute("aria-busy");
                                                                                                                                                                                            }
                                                                                                                                                                                                },


                                                                                                                                                                                                    showError(element, message) {
                                                                                                                                                                                                            if (element) {
                                                                                                                                                                                                                        element.textContent = message;
                                                                                                                                                                                                                                    element.setAttribute("role", "alert");
                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                },


                                                                                                                                                                                                                                                    clear(element) {
                                                                                                                                                                                                                                                            if (element) {
                                                                                                                                                                                                                                                                        element.textContent = "";
                                                                                                                                                                                                                                                                                    element.removeAttribute("role");
                                                                                                                                                                                                                                                                                                element.removeAttribute("aria-busy");
                                                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                                            },


                                                                                                                                                                                                                                                                                                                formatNumber(value) {
                                                                                                                                                                                                                                                                                                                        return new Intl.NumberFormat().format(value);
                                                                                                                                                                                                                                                                                                                            },


                                                                                                                                                                                                                                                                                                                                formatCurrency(amount, currency = "INR") {
                                                                                                                                                                                                                                                                                                                                        return new Intl.NumberFormat("en-IN", {
                                                                                                                                                                                                                                                                                                                                                    style: "currency",
                                                                                                                                                                                                                                                                                                                                                                currency: currency
                                                                                                                                                                                                                                                                                                                                                                        }).format(amount);
                                                                                                                                                                                                                                                                                                                                                                            }

                                                                                                                                                                                                                                                                                                                                                                            };