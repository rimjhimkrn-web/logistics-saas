(function () {
  "use strict";

  const form = document.getElementById("signInForm");
  const allowedPortals = new Set(["customer", "partner", "enterprise", "field"]);
  const params = new URLSearchParams(window.location.search);
  const portal = allowedPortals.has(params.get("portal")) ? params.get("portal") : "customer";
  const requestedReturn = params.get("return") || "/app/" + portal + "/";

  function safeReturnPath(value) {
    try {
      const target = new URL(value, window.location.origin);
      if (target.origin !== window.location.origin || !target.pathname.startsWith("/app/") || target.pathname === "/app/sign-in.html") return "/app/" + portal + "/";
      return target.pathname + target.search + target.hash;
    } catch (error) {
      return "/app/" + portal + "/";
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const button = form.querySelector("button[type=submit]");
    const values = new FormData(form);
    const email = String(values.get("email") || "").trim();
    const password = String(values.get("password") || "");
    const region = document.querySelector("[data-notifications]");
    region.replaceChildren();
    button.disabled = true;
    try {
      if (!window.KRIM) throw new Error("Authentication is unavailable.");
      const { error } = await window.KRIM.auth.signIn({ email, password });
      if (error) throw error;
      window.location.assign(safeReturnPath(requestedReturn));
    } catch (error) {
      window.KRIM.notifications.notify("Sign-in failed. Check your details or contact your organization administrator.", "error");
      console.error("Workspace sign-in failed.");
    } finally {
      button.disabled = false;
    }
  });
})();