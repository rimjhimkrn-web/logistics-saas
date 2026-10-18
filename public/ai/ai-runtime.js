/**
 * KRIM AI workspace runtime.
 * Safe baseline: validates inputs and explicitly reports that no AI service is configured.
 * It never fabricates predictions, results, audit events, or model output.
 */
const MAX_INPUT_LENGTH = 2000;
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-krim-ai-form]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      const status = form.parentElement.querySelector("[data-krim-ai-status]") ||
        document.querySelector("[data-krim-ai-status]");
      const data = new FormData(form);
      const values = [...data.entries()].map(([key, value]) => [key, String(value).trim()]);
      const invalid = values.some(([, value]) => !value || value.length > MAX_INPUT_LENGTH);
      if (invalid) {
        if (status) status.textContent = "Please provide a valid input (maximum 2,000 characters).";
        return;
      }
      if (status) {
        status.textContent = "Input validated locally. No AI request was sent: this workspace does not yet have a verified AI service endpoint, authentication flow, or result contract configured.";
      }
      form.dispatchEvent(new CustomEvent("krim:ai-input-validated", {
        bubbles: true,
        detail: { page: form.dataset.page || "unknown", fields: values.map(([key]) => key) }
      }));
    });
  });
});
