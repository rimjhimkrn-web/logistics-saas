(function (global) {
  "use strict";

  function element(tag, text, className) {
    const result = document.createElement(tag);
    if (text !== undefined && text !== null) result.textContent = String(text);
    if (className) result.className = className;
    return result;
  }

  function emptyState(title, message) {
    const state = element("section", null, "empty-state");
    state.append(element("h3", title), element("p", message));
    return state;
  }

  function loadingState(label) {
    const state = element("div", label || "Loading…", "loading-state");
    state.setAttribute("role", "status");
    state.setAttribute("aria-live", "polite");
    return state;
  }

  function errorState(title, message) {
    const state = emptyState(title, message);
    state.classList.add("empty-state--error");
    state.setAttribute("role", "alert");
    return state;
  }

  function statusBadge(label) {
    const badge = element("span", label || "Unknown", "status-badge");
    badge.dataset.status = String(label || "unknown").toLowerCase().replace(/[^a-z0-9_-]/g, "-");
    return badge;
  }

  function button(label, action, className) {
    const result = element("button", label, className || "button");
    result.type = "button";
    if (typeof action === "function") result.addEventListener("click", action);
    return result;
  }

  function confirm(message, confirmLabel) {
    return new Promise((resolve) => {
      const dialog = element("dialog", null, "confirm-dialog");
      const content = element("div", null, "confirm-dialog__content");
      content.append(element("p", message));
      const actions = element("div", null, "confirm-dialog__actions");
      const cancel = button("Cancel", () => { dialog.close("cancel"); }, "button button--quiet");
      const accept = button(confirmLabel || "Continue", () => { dialog.close("confirm"); }, "button");
      actions.append(cancel, accept);
      content.append(actions);
      dialog.append(content);
      dialog.addEventListener("close", () => {
        resolve(dialog.returnValue === "confirm");
        dialog.remove();
      }, { once: true });
      document.body.append(dialog);
      if (typeof dialog.showModal === "function") dialog.showModal();
      else {
        dialog.setAttribute("open", "");
        cancel.focus();
      }
    });
  }

  function validateFile(file, allowedTypes, maxBytes) {
    if (!file) return { valid: false, reason: "Choose a file." };
    if (!allowedTypes.includes(file.type)) return { valid: false, reason: "This file type is not allowed." };
    if (file.size > maxBytes) return { valid: false, reason: "This file is larger than the allowed size." };
    return { valid: true, reason: "" };
  }

  function externalLink(href, label) {
    let url;
    try { url = new URL(href); } catch (error) { return null; }
    if (url.protocol !== "https:") return null;
    const link = element("a", label);
    link.href = url.href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    return link;
  }

  global.KRIM_UI = Object.freeze({ element, emptyState, loadingState, errorState, statusBadge, button, confirm, validateFile, externalLink });
})(window);