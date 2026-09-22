/* =========================================================
   KRIM GLOBAL UI SERVICE
   Permanent Shared Frontend UI Layer
   ========================================================= */

(function () {

    "use strict";

    const KRIM_UI = {

        /* -------------------------------------------------
           DOM HELPERS
           ------------------------------------------------- */

        byId(id) {
            if (!id) return null;
            return document.getElementById(id);
        },


        query(selector, root = document) {
            if (!selector) return null;
            return root.querySelector(selector);
        },


        queryAll(selector, root = document) {
            if (!selector) return [];
            return Array.from(
                root.querySelectorAll(selector)
            );
        },


        /* -------------------------------------------------
           SAFE TEXT
           ------------------------------------------------- */

        escapeHtml(value) {

            if (value === null || value === undefined) {
                return "";
            }

            const div = document.createElement("div");

            div.textContent = String(value);

            return div.innerHTML;
        },


        /* -------------------------------------------------
           LOADING
           ------------------------------------------------- */

        setLoading(element, loading, text = "Loading...") {

            if (!element) return;

            if (loading) {

                if (!element.dataset.krimOriginalHtml) {
                    element.dataset.krimOriginalHtml =
                        element.innerHTML;
                }

                element.disabled = true;

                element.innerHTML =
                    '<span class="krim-loading">' +
                    '<span class="krim-loading-dot"></span>' +
                    this.escapeHtml(text) +
                    '</span>';

            } else {

                if (element.dataset.krimOriginalHtml) {

                    element.innerHTML =
                        element.dataset.krimOriginalHtml;

                    delete element.dataset.krimOriginalHtml;
                }

                element.disabled = false;
            }
        },


        showLoading(container, text = "Loading...") {

            if (!container) return;

            container.innerHTML =
                '<div class="krim-loading">' +
                '<span class="krim-loading-dot"></span>' +
                this.escapeHtml(text) +
                '</div>';
        },


        /* -------------------------------------------------
           STATUS / ALERT
           ------------------------------------------------- */

        alert(message, type = "info", target = null) {

            const allowedTypes = [
                "info",
                "success",
                "warning",
                "danger"
            ];

            if (!allowedTypes.includes(type)) {
                type = "info";
            }

            const alertElement =
                document.createElement("div");

            alertElement.className =
                "krim-alert krim-alert-" + type;

            alertElement.setAttribute(
                "role",
                "alert"
            );

            alertElement.textContent =
                message === null ||
                message === undefined
                    ? ""
                    : String(message);

            if (target) {

                const targetElement =
                    typeof target === "string"
                        ? this.query(target)
                        : target;

                if (targetElement) {
                    targetElement.innerHTML = "";
                    targetElement.appendChild(
                        alertElement
                    );
                    return alertElement;
                }
            }

            return alertElement;
        },


        toast(
            message,
            type = "info",
            duration = 4000
        ) {

            let container =
                document.getElementById(
                    "krim-toast-container"
                );

            if (!container) {

                container =
                    document.createElement("div");

                container.id =
                    "krim-toast-container";

                container.style.position = "fixed";
                container.style.top = "20px";
                container.style.right = "20px";
                container.style.zIndex = "2000";
                container.style.display = "flex";
                container.style.flexDirection = "column";
                container.style.gap = "10px";
                container.style.maxWidth = "min(380px, calc(100vw - 32px))";

                document.body.appendChild(
                    container
                );
            }

            const toast =
                this.alert(
                    message,
                    type
                );

            toast.style.boxShadow =
                "0 8px 24px rgba(16,24,40,0.12)";

            toast.style.background =
                "white";

            toast.style.transition =
                "opacity 0.2s ease, transform 0.2s ease";

            container.appendChild(toast);

            window.setTimeout(function () {

                toast.style.opacity = "0";
                toast.style.transform =
                    "translateY(-4px)";

                window.setTimeout(function () {

                    if (toast.parentNode) {
                        toast.parentNode.removeChild(
                            toast
                        );
                    }

                }, 220);

            }, Math.max(1000, duration));

            return toast;
        },


        /* -------------------------------------------------
           MODAL
           ------------------------------------------------- */

        openModal({
            title = "KRIM",
            content = "",
            footer = "",
            closeButton = true
        } = {}) {

            this.closeModal();

            const backdrop =
                document.createElement("div");

            backdrop.className =
                "krim-modal-backdrop";

            backdrop.id =
                "krim-global-modal";

            const modal =
                document.createElement("div");

            modal.className =
                "krim-modal";

            modal.setAttribute(
                "role",
                "dialog"
            );

            modal.setAttribute(
                "aria-modal",
                "true"
            );

            const header =
                document.createElement("div");

            header.className =
                "krim-modal-header";

            const heading =
                document.createElement("strong");

            heading.textContent =
                title;

            header.appendChild(
                heading
            );

            if (closeButton) {

                const close =
                    document.createElement("button");

                close.type = "button";

                close.className =
                    "krim-icon-button";

                close.setAttribute(
                    "aria-label",
                    "Close"
                );

                close.textContent = "×";

                close.addEventListener(
                    "click",
                    () => this.closeModal()
                );

                header.appendChild(
                    close
                );
            }

            const body =
                document.createElement("div");

            body.className =
                "krim-modal-body";

            if (typeof content === "string") {
                body.innerHTML = content;
            } else if (content instanceof Node) {
                body.appendChild(content);
            }

            modal.appendChild(
                header
            );

            modal.appendChild(
                body
            );

            if (footer) {

                const footerElement =
                    document.createElement("div");

                footerElement.className =
                    "krim-modal-footer";

                if (typeof footer === "string") {
                    footerElement.innerHTML =
                        footer;
                } else if (
                    footer instanceof Node
                ) {
                    footerElement.appendChild(
                        footer
                    );
                }

                modal.appendChild(
                    footerElement
                );
            }

            backdrop.appendChild(
                modal
            );

            backdrop.addEventListener(
                "click",
                (event) => {

                    if (
                        event.target === backdrop
                    ) {
                        this.closeModal();
                    }

                }
            );

            document.body.appendChild(
                backdrop
            );

            document.body.style.overflow =
                "hidden";

            return backdrop;
        },


        closeModal() {

            const modal =
                document.getElementById(
                    "krim-global-modal"
                );

            if (modal) {
                modal.remove();
            }

            document.body.style.overflow =
                "";
        },


        /* -------------------------------------------------
           FORM HELPERS
           ------------------------------------------------- */

        getFormData(form) {

            if (!form) {
                throw new Error(
                    "Form element is required."
                );
            }

            const formData =
                new FormData(form);

            const result = {};

            formData.forEach(
                (value, key) => {

                    if (
                        Object.prototype.hasOwnProperty
                            .call(result, key)
                    ) {

                        if (
                            !Array.isArray(
                                result[key]
                            )
                        ) {
                            result[key] = [
                                result[key]
                            ];
                        }

                        result[key].push(
                            value
                        );

                    } else {

                        result[key] = value;
                    }

                }
            );

            return result;
        },


        clearForm(form) {

            if (!form) return;

            if (
                typeof form.reset ===
                "function"
            ) {
                form.reset();
            }
        },


        /* -------------------------------------------------
           TEXT / NUMBER FORMATTERS
           ------------------------------------------------- */

        formatNumber(
            value,
            locale = KRIM_CONFIG.market.defaultLanguage
        ) {

            const number =
                Number(value);

            if (!Number.isFinite(number)) {
                return "0";
            }

            return new Intl.NumberFormat(
                locale
            ).format(number);
        },


        formatCurrency(
            value,
            currency =
                KRIM_CONFIG.market.defaultCurrency,
            locale =
                KRIM_CONFIG.market.defaultLanguage
        ) {

            const number =
                Number(value);

            if (!Number.isFinite(number)) {
                return "—";
            }

            return new Intl.NumberFormat(
                locale,
                {
                    style: "currency",
                    currency: currency
                }
            ).format(number);
        },


        formatDate(
            value,
            locale =
                KRIM_CONFIG.market.defaultLanguage
        ) {

            if (!value) {
                return "—";
            }

            const date =
                new Date(value);

            if (
                Number.isNaN(
                    date.getTime()
                )
            ) {
                return "—";
            }

            return new Intl.DateTimeFormat(
                locale,
                {
                    year: "numeric",
                    month: "short",
                    day: "numeric"
                }
            ).format(date);
        },


        /* -------------------------------------------------
           URL HELPERS
           ------------------------------------------------- */

        goTo(path) {

            if (!path) return;

            window.location.href =
                new URL(
                    path,
                    window.location.href
                ).href;
        },


        /* -------------------------------------------------
           KEYBOARD / ACCESSIBILITY
           ------------------------------------------------- */

        bindEscapeToModal() {

            document.addEventListener(
                "keydown",
                (event) => {

                    if (
                        event.key === "Escape"
                    ) {
                        this.closeModal();
                    }

                }
            );
        },


        /* -------------------------------------------------
           INITIALIZATION
           ------------------------------------------------- */

        init() {

            this.bindEscapeToModal();

            return true;
        }

    };


    window.KRIM_UI =
        KRIM_UI;


    if (
        document.readyState ===
        "loading"
    ) {

        document.addEventListener(
            "DOMContentLoaded",
            () => KRIM_UI.init(),
            {
                once: true
            }
        );

    } else {

        KRIM_UI.init();
    }

})();
