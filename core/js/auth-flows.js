(function () {
  "use strict";

  const form = document.querySelector("[data-auth-flow]");
  if (!form) return;

  const mode = form.dataset.authFlow;
  const notifications = document.querySelector("[data-notifications]");
  const password = form.elements.password;
  const confirmation = form.elements.confirm_password;

  function showMessage(message, type) {
    const notice = document.createElement("div");
    notice.className = "notice notice--" + (type || "info");
    notice.setAttribute("role", type === "error" ? "alert" : "status");
    notice.textContent = message;
    notifications.replaceChildren(notice);
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;

    if (mode === "reset" && password.value !== confirmation.value) {
      confirmation.setCustomValidity("Passwords do not match.");
      confirmation.reportValidity();
      confirmation.setCustomValidity("");
      return;
    }

    const submit = form.querySelector("[type=submit]");
    const values = new FormData(form);
    const email = String(values.get("email") || "").trim();
    submit.disabled = true;
    notifications.replaceChildren();

    try {
      let result;
      if (mode === "register") {
        result = await window.KRIM.auth.signUp({
          email,
          password: String(values.get("password") || "")
        });
      } else if (mode === "recovery") {
        result = await window.KRIM.auth.requestPasswordReset(email);
      } else if (mode === "reset") {
        result = await window.KRIM.auth.updatePassword(String(values.get("password") || ""));
      } else {
        throw new Error("This authentication action is unavailable.");
      }

      if (result.error) throw result.error;

      if (mode === "register") {
        showMessage("Account request submitted. Verify your email if prompted; workspace access still requires an authorized organization membership.", "success");
        form.reset();
      } else if (mode === "recovery") {
        showMessage("If this address can receive account recovery, instructions will be sent shortly.", "success");
        form.reset();
      } else {
        showMessage("Password updated. Return to sign in with the new password.", "success");
        form.reset();
        submit.disabled = true;
        window.setTimeout(() => window.location.assign("/app/sign-in.html"), 1200);
      }
    } catch (error) {
      console.error("Authentication flow failed.");
      showMessage("This authentication request could not be completed. Check the details or contact your organization administrator.", "error");
    } finally {
      if (mode !== "reset" || notifications.querySelector(".notice--error")) submit.disabled = false;
    }
  });
})();
