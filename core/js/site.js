(function () {
  "use strict";

  const menuToggle = document.querySelector("[data-menu-toggle]");
  const mainNav = document.getElementById("mainNav");
  const quoteForm = document.getElementById("quoteForm");
  const notificationRegion = document.querySelector("[data-notifications]");
  const authNavigation = document.querySelector("[data-auth-navigation]");

  document.getElementById("currentYear").textContent = String(new Date().getFullYear());

  async function updateAuthNavigation() {
    const { data, error } = await window.KRIM.auth.session();
    if (error || !data.session) return;
    authNavigation.href = "/app/customer/";
    authNavigation.textContent = "Open customer workspace";
    authNavigation.removeAttribute("data-i18n");
  }

  updateAuthNavigation().catch(() => {
    console.warn("Authenticated navigation could not be resolved.");
  });
  window.KRIM.auth.onStateChange((event, session) => {
    if (session) {
      authNavigation.href = "/app/customer/";
      authNavigation.textContent = "Open customer workspace";
      authNavigation.removeAttribute("data-i18n");
    } else {
      authNavigation.href = "/app/sign-in.html?portal=customer";
      authNavigation.textContent = window.KRIM.i18n.translate("signIn");
      authNavigation.dataset.i18n = "signIn";
    }
  });

  if (menuToggle && mainNav) {
    menuToggle.addEventListener("click", () => {
      const expanded = menuToggle.getAttribute("aria-expanded") === "true";
      menuToggle.setAttribute("aria-expanded", String(!expanded));
      menuToggle.setAttribute("aria-label", expanded ? "Open navigation" : "Close navigation");
      mainNav.classList.toggle("is-open", !expanded);
    });
    mainNav.addEventListener("click", (event) => {
      if (!event.target.closest("a")) return;
      mainNav.classList.remove("is-open");
      menuToggle.setAttribute("aria-expanded", "false");
    });
  }

  quoteForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!quoteForm.reportValidity()) return;

    const button = quoteForm.querySelector("[data-submit-label]");
    const originalText = button.textContent;
    const values = Object.fromEntries(new FormData(quoteForm).entries());
    for (const key of Object.keys(values)) values[key] = String(values[key]).trim();
    if (Object.values(values).some((value) => value.length === 0)) {
      window.KRIM.notifications.notify("Complete each field before sending your request.", "error");
      return;
    }

    notificationRegion.replaceChildren();
    button.disabled = true;
    button.textContent = "Sending...";
    try {
      await window.KRIM.api.createShipmentRequest(values);
      quoteForm.reset();
      window.KRIM.notifications.notify(window.KRIM.i18n.translate("requestSent"), "success");
    } catch (error) {
      console.error("Shipment request could not be submitted.");
      window.KRIM.notifications.notify("We could not submit this request. Please try again later.", "error");
    } finally {
      button.disabled = false;
      button.textContent = originalText;
    }
  });

  document.getElementById("trackingForm").addEventListener("submit", (event) => {
    event.preventDefault();
    const reference = document.getElementById("trackingReference");
    if (!reference.reportValidity()) return;
    document.getElementById("trackingResult").textContent =
      "Live tracking is not connected yet. Contact your KRIM representative for a verified status.";
  });

  const installButton = document.querySelector("[data-install]");
  window.addEventListener("beforeinstallprompt", (event) => {
    installButton.hidden = !window.KRIM.pwa.canPromptInstall();
  });
  installButton.addEventListener("click", async () => {
    if (!window.KRIM.pwa.canPromptInstall()) return;
    installButton.disabled = true;
    try {
      await window.KRIM.pwa.promptInstall();
    } catch (error) {
      console.warn("Install prompt could not be opened.");
    } finally {
      installButton.hidden = true;
      installButton.disabled = false;
    }
  });
  window.addEventListener("appinstalled", () => {
    installButton.hidden = true;
  });

  if ("serviceWorker" in navigator && window.isSecureContext) {
    navigator.serviceWorker.register("/service-worker.js").catch(() => {
      console.warn("Offline shell registration unavailable in this browser context.");
    });
  }
})();