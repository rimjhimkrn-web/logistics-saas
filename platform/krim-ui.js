/* =========================================================
   KRIM UI SERVICE
   Permanent shared frontend UI utilities
   ========================================================= */

(function () {
    "use strict";

    const KRIM_UI = {};


    /* -------------------------------------------------------
       DOM HELPERS
       ------------------------------------------------------- */

    KRIM_UI.qs = function (selector, root) {
        const scope = root || document;
        return scope.querySelector(selector);
    };


    KRIM_UI.qsa = function (selector, root) {
        const scope = root || document;
        return Array.from(
            scope.querySelectorAll(selector)
        );
    };


    KRIM_UI.create = function (tag, options) {
        const element =
            document.createElement(tag || "div");

        const config = options || {};

        if (config.className) {
            element.className = config.className;
        }

        if (config.text !== undefined) {
            element.textContent = String(config.text);
        }

        if (config.attributes) {
            Object.entries(config.attributes)
                .forEach(function ([name, value]) {
                    element.setAttribute(
                        name,
                        String(value)
                    );
                });
        }

        return element;
    };


    /* -------------------------------------------------------
       SAFE TEXT
       ------------------------------------------------------- */

    KRIM_UI.setText = function (element, value) {
        if (!element) {
            return;
        }

        element.textContent =
            value === null ||
            value === undefined
                ? ""
                : String(value);
    };


    KRIM_UI.escapeHTML = function (value) {
        const div =
            document.createElement("div");

        div.textContent =
            value === null ||
            value === undefined
                ? ""
                : String(value);

        return div.innerHTML;
    };


    /* -------------------------------------------------------
       LOADING STATE
       ------------------------------------------------------- */

    KRIM_UI.setLoading = function (
        element,
        loading,
        options
    ) {
        if (!element) {
            return;
        }

        const config = options || {};

        if (loading) {

            if (!element.dataset.krimOriginalText) {
                element.dataset.krimOriginalText =
                    element.textContent;
            }

            element.disabled = true;

            if (config.text) {
                element.textContent =
                    String(config.text);
            }

            element.setAttribute(
                "aria-busy",
                "true"
            );

            element.classList.add(
                "is-loading"
            );

        } else {

            if (
                element.dataset.krimOriginalText !==
                undefined
            ) {
                element.textContent =
                    element.dataset.krimOriginalText;

                delete element.dataset.krimOriginalText;
            }

            element.disabled = false;

            element.removeAttribute(
                "aria-busy"
            );

            element.classList.remove(
                "is-loading"
            );
        }
    };


    /* -------------------------------------------------------
       ALERT / MESSAGE
       ------------------------------------------------------- */

    KRIM_UI.showAlert = function (
        container,
        message,
        type
    ) {
        if (!container) {
            return null;
        }

        const alert =
            KRIM_UI.create("div", {
                className:
                    "krim-alert " +
                    "krim-alert-" +
                    (type || "info")
            });

        alert.setAttribute(
            "role",
            type === "danger"
                ? "alert"
                : "status"
        );

        KRIM_UI.setText(
            alert,
            message
        );

        container.innerHTML = "";
        container.appendChild(alert);

        return alert;
    };


    /* -------------------------------------------------------
       TOAST
       ------------------------------------------------------- */

    KRIM_UI.toast = function (
        message,
        type,
        duration
    ) {
        const toast =
            KRIM_UI.create("div", {
                className:
                    "krim-toast krim-toast-" +
                    (type || "info")
            });

        toast.setAttribute(
            "role",
            "status"
        );

        KRIM_UI.setText(
            toast,
            message
        );

        let container =
            document.querySelector(
                "[data-krim-toast-container]"
            );

        if (!container) {
            container =
                KRIM_UI.create("div", {
                    className:
                        "krim-toast-container"
                });

            container.dataset.krimToastContainer =
                "true";

            document.body.appendChild(
                container
            );
        }

        container.appendChild(toast);

        const timeout =
            Number.isFinite(duration) &&
            duration > 0
                ? duration
                : 3500;

        window.setTimeout(
            function () {
                toast.remove();

                if (
                    container.children.length === 0
                ) {
                    container.remove();
                }
            },
            timeout
        );

        return toast;
    };


    /* -------------------------------------------------------
       MODAL
       ------------------------------------------------------- */

    KRIM_UI.openModal = function (
        options
    ) {
        const config = options || {};

        const backdrop =
            KRIM_UI.create("div", {
                className:
                    "krim-modal-backdrop"
            });

        backdrop.setAttribute(
            "role",
            "presentation"
        );

        const modal =
            KRIM_UI.create("div", {
                className:
                    "krim-modal"
            });

        modal.setAttribute(
            "role",
            "dialog"
        );

        modal.setAttribute(
            "aria-modal",
            "true"
        );

        if (config.label) {
            modal.setAttribute(
                "aria-label",
                String(config.label)
            );
        }


        const header =
            KRIM_UI.create("div", {
                className:
                    "krim-modal-header"
            });


        const title =
            KRIM_UI.create("h2", {
                className:
                    "krim-modal-title",
                text:
                    config.title || ""
            });


        const closeButton =
            KRIM_UI.create("button", {
                className:
                    "krim-icon-btn",
                text: "×",
                attributes: {
                    type: "button",
                    "aria-label": "Close"
                }
            });


        header.appendChild(title);
        header.appendChild(closeButton);


        const body =
            KRIM_UI.create("div", {
                className:
                    "krim-modal-body"
            });


        const footer =
            KRIM_UI.create("div", {
                className:
                    "krim-modal-footer"
            });


        if (config.content instanceof Node) {
            body.appendChild(
                config.content
            );
        } else if (
            config.content !== undefined
        ) {
            KRIM_UI.setText(
                body,
                config.content
            );
        }


        if (config.footer instanceof Node) {
            footer.appendChild(
                config.footer
            );
        } else if (
            config.footer !== undefined
        ) {
            KRIM_UI.setText(
                footer,
                config.footer
            );
        }


        modal.appendChild(header);
        modal.appendChild(body);


        if (
            config.footer !== undefined
        ) {
            modal.appendChild(footer);
        }


        backdrop.appendChild(modal);
        document.body.appendChild(backdrop);


        function close() {
            backdrop.remove();

            if (
                typeof config.onClose ===
                "function"
            ) {
                config.onClose();
            }
        }


        closeButton.addEventListener(
            "click",
            close
        );


        if (config.closeOnBackdrop !== false) {
            backdrop.addEventListener(
                "click",
                function (event) {
                    if (
                        event.target === backdrop
                    ) {
                        close();
                    }
                }
            );
        }


        const escapeHandler =
            function (event) {
                if (
                    event.key === "Escape"
                ) {
                    close();
                    document.removeEventListener(
                        "keydown",
                        escapeHandler
                    );
                }
            };


        document.addEventListener(
            "keydown",
            escapeHandler
        );


        return {
            element: backdrop,
            modal: modal,
            close: close
        };
    };


    /* -------------------------------------------------------
       FORM HELPERS
       ------------------------------------------------------- */

    KRIM_UI.getFormData = function (
        form
    ) {
        if (!form) {
            throw new Error(
                "Form element is required."
            );
        }

        return Object.fromEntries(
            new FormData(form).entries()
        );
    };


    KRIM_UI.resetForm = function (
        form
    ) {
        if (!form) {
            return;
        }

        form.reset();
    };


    /* -------------------------------------------------------
       NUMBER FORMATTING
       ------------------------------------------------------- */

    KRIM_UI.formatNumber = function (
        value,
        options
    ) {
        const config = options || {};

        const locale =
            config.locale ||
            (
                window.KRIM_CONFIG &&
                window.KRIM_CONFIG.settings &&
                window.KRIM_CONFIG.settings.numberLocale
            ) ||
            "en-IN";

        const number =
            Number(value);

        if (!Number.isFinite(number)) {
            return "—";
        }

        return new Intl.NumberFormat(
            locale,
            config.formatOptions || {}
        ).format(number);
    };


    /* -------------------------------------------------------
       CURRENCY FORMATTING
       ------------------------------------------------------- */

    KRIM_UI.formatCurrency = function (
        value,
        currency,
        options
    ) {
        const config = options || {};

        const code =
            currency ||
            (
                window.KRIM_CONFIG &&
                window.KRIM_CONFIG.market &&
                window.KRIM_CONFIG.market.defaultCurrency
            ) ||
            "INR";

        const locale =
            config.locale ||
            (
                window.KRIM_CONFIG &&
                window.KRIM_CONFIG.settings &&
                window.KRIM_CONFIG.settings.numberLocale
            ) ||
            "en-IN";

        const number =
            Number(value);

        if (!Number.isFinite(number)) {
            return "—";
        }

        return new Intl.NumberFormat(
            locale,
            {
                style: "currency",
                currency: code,
                maximumFractionDigits:
                    config.maximumFractionDigits !== undefined
                        ? config.maximumFractionDigits
                        : 2
            }
        ).format(number);
    };


    /* -------------------------------------------------------
       DATE FORMATTING
       ------------------------------------------------------- */

    KRIM_UI.formatDate = function (
        value,
        options
    ) {
        if (!value) {
            return "—";
        }

        const date =
            value instanceof Date
                ? value
                : new Date(value);

        if (
            Number.isNaN(
                date.getTime()
            )
        ) {
            return "—";
        }

        const config = options || {};

        return new Intl.DateTimeFormat(
            config.locale || "en-IN",
            config.formatOptions || {
                day: "2-digit",
                month: "short",
                year: "numeric"
            }
        ).format(date);
    };


    /* -------------------------------------------------------
       DATE + TIME
       ------------------------------------------------------- */

    KRIM_UI.formatDateTime = function (
        value,
        options
    ) {
        if (!value) {
            return "—";
        }

        const date =
            value instanceof Date
                ? value
                : new Date(value);

        if (
            Number.isNaN(
                date.getTime()
            )
        ) {
            return "—";
        }

        const config = options || {};

        return new Intl.DateTimeFormat(
            config.locale || "en-IN",
            config.formatOptions || {
                day: "2-digit",
                month: "short",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit"
            }
        ).format(date);
    };


    /* -------------------------------------------------------
       URL HELPERS
       ------------------------------------------------------- */

    KRIM_UI.toAbsoluteUrl = function (
        path
    ) {
        return new URL(
            String(path || ""),
            window.location.origin
        ).href;
    };


    KRIM_UI.navigate = function (
        path
    ) {
        window.location.href =
            KRIM_UI.toAbsoluteUrl(path);
    };


    /* -------------------------------------------------------
       EVENT HELPER
       ------------------------------------------------------- */

    KRIM_UI.on = function (
        element,
        event,
        handler,
        options
    ) {
        if (!element) {
            return function () {};
        }

        element.addEventListener(
            event,
            handler,
            options
        );

        return function () {
            element.removeEventListener(
                event,
                handler,
                options
            );
        };
    };


    /* -------------------------------------------------------
       ESCAPE KEY SUPPORT
       ------------------------------------------------------- */

    KRIM_UI.onEscape = function (
        callback
    ) {
        if (
            typeof callback !==
            "function"
        ) {
            throw new Error(
                "Escape callback must be a function."
            );
        }

        const handler =
            function (event) {
                if (
                    event.key === "Escape"
                ) {
                    callback(event);
                }
            };

        document.addEventListener(
            "keydown",
            handler
        );

        return function () {
            document.removeEventListener(
                "keydown",
                handler
            );
        };
    };


    /* -------------------------------------------------------
       INITIALIZATION
       ------------------------------------------------------- */

    KRIM_UI.init = function () {
        document.documentElement
            .classList.add(
                "krim-ui-ready"
            );
    };


    /*
     * -------------------------------------------------------
     * PUBLIC API
     * -------------------------------------------------------
     */

    window.KRIM_UI = Object.freeze(
        KRIM_UI
    );


    /*
     * -------------------------------------------------------
     * AUTO INITIALIZATION
     * -------------------------------------------------------
     */

    if (
        document.readyState ===
        "loading"
    ) {
        document.addEventListener(
            "DOMContentLoaded",
            KRIM_UI.init,
            {
                once: true
            }
        );
    } else {
        KRIM_UI.init();
    }

})();
