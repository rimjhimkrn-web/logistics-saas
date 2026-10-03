(function () {
  "use strict";

  const role = document.body.dataset.portal;
  const appNav = document.getElementById("appNav");
  const content = document.getElementById("appContent");
  const sidebar = document.getElementById("portalSide");
  const notificationRegion = document.querySelector("[data-notifications]");
  const fieldQueueName = "krim-field-queue-v1";

  const views = {
    customer: [
      ["overview", "Overview", "dashboard"], ["shipments", "Shipments", "shipments"], ["create", "Create shipment", "requestQuote"], ["tracking", "Tracking", "trackShipment"], ["quotes", "Quotes"], ["payments", "Payments"], ["invoices", "Invoices"], ["documents", "Documents", "documents"], ["notifications", "Notifications", "notifications"], ["support", "Support", "support"]
    ],
    partner: [
      ["overview", "Overview", "dashboard"], ["opportunities", "Available opportunities"], ["loads", "Loads"], ["capacity", "Capacity"], ["shipments", "Shipments", "shipments"], ["tracking", "Tracking updates", "trackShipment"], ["documents", "Documents", "documents"], ["earnings", "Earnings & settlements"], ["compliance", "Compliance"], ["performance", "Performance"]
    ],
    enterprise: [
      ["overview", "Overview", "dashboard"], ["users", "Users"], ["shipments", "Shipments", "shipments"], ["quotes", "Quotes"], ["finance", "Finance"], ["analytics", "Analytics"], ["documents", "Documents", "documents"], ["integrations", "Integrations"], ["ai-activity", "AI activity"], ["recommendations", "Recommendations & evidence"], ["approvals", "Approval queue"], ["automation", "Automation status"], ["pause", "Emergency pause"], ["memory", "Institutional memory"]
    ],
    field: [
      ["assigned", "Assigned work"], ["pickup-delivery", "Pickup / delivery"], ["events", "Tracking events"], ["proof", "Proof of delivery"], ["queue", "Offline queue"]
    ]
  };

  const currentViews = views[role] || views.customer;

  function node(tag, text, className) {
    if (window.KRIM_UI) return window.KRIM_UI.element(tag, text, className);
    const element = document.createElement(tag);
    if (text !== undefined && text !== null) element.textContent = text;
    if (className) element.className = className;
    return element;
  }

  function emptyState(title, message) {
    return window.KRIM_UI ? window.KRIM_UI.emptyState(title, message) : node("section", title + " " + message, "empty-state");
  }

  function notify(message, type) {
    window.KRIM.notifications.notify(message, type || "info");
  }

  function buildNavigation() {
    appNav.replaceChildren();
    currentViews.forEach(([id, title, translationKey]) => {
      const link = node("a", null);
      link.href = "#" + id;
      link.textContent = translationKey ? window.KRIM.i18n.translate(translationKey) : title;
      link.dataset.view = id;
      if (id === (window.location.hash.slice(1) || currentViews[0][0])) link.setAttribute("aria-current", "page");
      appNav.append(link);
    });
  }

  function buildTable(rows) {
    const wrap = node("div", null, "data-table-wrap");
    const table = node("table", null, "data-table");
    const head = node("thead");
    const headerRow = node("tr");
    ["Reference", "Pickup", "Delivery", "Goods", "Status", "Created"].forEach((label) => headerRow.append(node("th", label)));
    head.append(headerRow);
    const body = node("tbody");
    rows.forEach((shipment) => {
      const row = node("tr");
      [shipment.id, shipment.pickup_location, shipment.delivery_location, shipment.material_goods].forEach((value) => row.append(node("td", value == null ? "" : String(value))));
      const statusCell = node("td");
      statusCell.append(window.KRIM_UI.statusBadge(shipment.status || "Pending"));
      row.append(statusCell, node("td", shipment.created_at ? window.KRIM.market.formatDate(shipment.created_at) : ""));
      body.append(row);
    });
    table.append(head, body);
    wrap.append(table);
    return wrap;
  }

  async function renderShipments(target) {
    target.append(node("p", "Shipment records are returned only when the existing backend permits access.", "muted"));
    const loading = window.KRIM_UI.loadingState("Loading shipment data…");
    target.append(loading);
    try {
      const shipments = await window.KRIM.api.listShipmentRequests();
      loading.remove();
      target.append(shipments.length ? buildTable(shipments) : emptyState("No shipment requests to show", "When an authorized shipment request is available, it will appear here."));
    } catch (error) {
      loading.remove();
      target.append(window.KRIM_UI.errorState("Shipment data unavailable", "The current account cannot retrieve shipment data, or the data source is unavailable. Backend access rules remain in force."));
    }
  }

  function addRequestField(form, label, name, type, maxLength) {
    const wrapper = node("div", null, "field");
    const inputId = "request-" + name;
    const labelNode = node("label", label);
    labelNode.htmlFor = inputId;
    const input = node("input");
    input.id = inputId;
    input.name = name;
    input.type = type || "text";
    input.maxLength = maxLength;
    input.required = true;
    wrapper.append(labelNode, input);
    form.append(wrapper);
  }

  function renderCreateRequest(target) {
    target.append(node("p", "Service availability is confirmed per request. Do not include sensitive personal or payment details.", "muted"));
    const form = node("form", null, "request-form");
    [["Pickup location", "pickup_location", 160], ["Delivery location", "delivery_location", 160], ["Goods / material", "material_goods", 160], ["Weight", "weight", 80], ["Vehicle type", "truck_type", 100], ["Contact name", "customer_name", 120], ["Phone", "phone_number", 32]].forEach((field) => addRequestField(form, field[0], field[1], field[1] === "phone_number" ? "tel" : "text", field[2]));
    const submit = node("button", "Send shipment request →", "button");
    submit.type = "submit";
    form.append(submit);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!form.reportValidity()) return;
      const values = Object.fromEntries(new FormData(form).entries());
      Object.keys(values).forEach((key) => { values[key] = String(values[key]).trim(); });
      if (Object.values(values).some((value) => !value)) return notify("Complete each field before sending your request.", "error");
      submit.disabled = true;
      try {
        await window.KRIM.api.createShipmentRequest(values);
        form.reset();
        notify(window.KRIM.i18n.translate("requestSent"), "success");
      } catch (error) {
        notify("The request could not be submitted. Please try again later.", "error");
      } finally {
        submit.disabled = false;
      }
    });
    target.append(form);
  }

  function renderFieldUpdate(target) {
    target.append(emptyState("Assigned task data is not connected", "Use a task reference supplied by your dispatcher. This local draft is not sent to KRIM and is not a confirmed tracking event."));
    const form = node("form", null, "field-update-form");
    addRequestField(form, "Task reference", "task_ref", "text", 80);
    const selectorWrap = node("div", null, "field");
    const selectorLabel = node("label", "Update type");
    selectorLabel.htmlFor = "field-event-type";
    const selector = node("select");
    selector.id = "field-event-type";
    selector.name = "event_type";
    [["pickup", "Pickup"], ["in_transit", "In transit"], ["delivery", "Delivery"], ["exception", "Exception"]].forEach(([value, label]) => {
      const option = node("option", label);
      option.value = value;
      selector.append(option);
    });
    selectorWrap.append(selectorLabel, selector);
    const noteWrap = node("div", null, "field");
    const noteLabel = node("label", "Short note (no personal data)");
    noteLabel.htmlFor = "field-note";
    const note = node("textarea");
    note.id = "field-note";
    note.name = "note";
    note.maxLength = 300;
    noteWrap.append(noteLabel, note);
    const save = node("button", "Save local draft", "button");
    save.type = "submit";
    form.append(selectorWrap, noteWrap, save);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!form.reportValidity()) return;
      const values = Object.fromEntries(new FormData(form).entries());
      values.task_ref = String(values.task_ref).trim();
      values.note = String(values.note).trim();
      if (!values.task_ref) return notify("Enter a task reference.", "error");
      save.disabled = true;
      try {
        await queueAction({ id: crypto.randomUUID(), ...values, createdAt: new Date().toISOString() });
        form.reset();
        notify("Saved on this device only. This event has not been sent or confirmed.", "success");
      } catch (error) {
        notify("This browser could not save a local draft.", "error");
      } finally {
        save.disabled = false;
      }
    });
    target.append(form, emptyState("Offline queue", "Drafts stay on this device until removed. There is no field-update sync endpoint configured."));
  }

  function openQueue() {
    return new Promise((resolve, reject) => {
      if (!window.indexedDB) return reject(new Error("IndexedDB unavailable"));
      const request = indexedDB.open(fieldQueueName, 1);
      request.onupgradeneeded = () => request.result.createObjectStore("actions", { keyPath: "id" });
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function queueAction(action) {
    const db = await openQueue();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction("actions", "readwrite");
      transaction.objectStore("actions").put(action);
      transaction.oncomplete = () => { db.close(); resolve(); };
      transaction.onerror = () => { db.close(); reject(transaction.error); };
    });
  }

  async function readQueue() {
    const db = await openQueue();
    return new Promise((resolve, reject) => {
      const request = db.transaction("actions", "readonly").objectStore("actions").getAll();
      request.onsuccess = () => { db.close(); resolve(request.result); };
      request.onerror = () => { db.close(); reject(request.error); };
    });
  }

  async function removeQueueItem(id) {
    const db = await openQueue();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction("actions", "readwrite");
      transaction.objectStore("actions").delete(id);
      transaction.oncomplete = () => { db.close(); resolve(); };
      transaction.onerror = () => { db.close(); reject(transaction.error); };
    });
  }

  async function clearQueue() {
    try {
      const db = await openQueue();
      await new Promise((resolve, reject) => {
        const transaction = db.transaction("actions", "readwrite");
        transaction.objectStore("actions").clear();
        transaction.oncomplete = resolve;
        transaction.onerror = () => reject(transaction.error);
      });
      db.close();
    } catch (error) {
      console.warn("Field drafts could not be cleared.");
    }
  }

  async function renderQueue(target) {
    target.append(node("p", "Draft actions are local to this browser and have not been delivered to KRIM. Avoid shared devices; signing out clears the local queue.", "muted"));
    try {
      const actions = await readQueue();
      if (!actions.length) return target.append(emptyState("Queue is empty", "No local field drafts are stored on this device."));
      actions.forEach((action) => {
        const card = node("article", null, "portal-card surface queue-item");
        card.append(node("h2", action.event_type + " · " + action.task_ref), node("p", action.note || "No note"), node("p", "Local draft · " + window.KRIM.market.formatDate(action.createdAt)));
        const remove = node("button", "Remove", "button button--outline");
        remove.type = "button";
        remove.addEventListener("click", async () => {
          if (!await window.KRIM_UI.confirm("Remove this local draft from this device?", "Remove draft")) return;
          await removeQueueItem(action.id);
          renderView();
        });
        card.append(remove);
        target.append(card);
      });
    } catch (error) {
      target.append(emptyState("Offline storage unavailable", "This browser could not open its local field queue."));
    }
  }

  function renderProofOfDelivery(target) {
    target.append(emptyState("Secure upload service not connected", "Proof files are not uploaded or stored. Connect an authorized backend upload workflow before submitting delivery evidence."));
    const wrapper = node("div", null, "field proof-upload");
    const label = node("label", "Choose a PDF, JPEG, or PNG proof file (maximum 5 MB)");
    label.htmlFor = "proof-file";
    const input = node("input");
    input.id = "proof-file";
    input.type = "file";
    input.accept = "application/pdf,image/jpeg,image/png";
    input.setAttribute("aria-describedby", "proof-status");
    const status = node("p", "No file selected. Nothing will be uploaded.", "muted");
    status.id = "proof-status";
    input.addEventListener("change", () => {
      const file = input.files && input.files[0];
      if (!file) return;
      const validTypes = ["application/pdf", "image/jpeg", "image/png"];
      const validation = window.KRIM_UI.validateFile(file, validTypes, 5 * 1024 * 1024);
      if (!validation.valid) {
        input.value = "";
        status.textContent = "File rejected. " + validation.reason;
        return;
      }
      status.textContent = "File type and size look valid. No upload endpoint is configured; file remains unsubmitted.";
    });
    wrapper.append(label, input, status);
    target.append(wrapper);
  }

  async function renderView() {
    const requestedId = window.location.hash.slice(1);
    const selected = currentViews.find((view) => view[0] === requestedId) || currentViews[0];
    appNav.querySelectorAll("a").forEach((link) => {
      const active = link.dataset.view === selected[0];
      link.setAttribute("aria-current", active ? "page" : "false");
    });
    content.replaceChildren();
    const eyebrow = node("span", role.toUpperCase() + " WORKSPACE", "eyebrow");
    const title = node("h1", selected[1]);
    content.append(eyebrow, title);

    if (selected[0] === "overview") {
      content.append(node("p", "Workspace information is shown only when an authorized data source is available.", "muted"));
      const cards = node("div", null, "grid portal-grid");
      currentViews.filter((view) => view[0] !== "overview").slice(0, 6).forEach((view) => {
        const card = node("article", null, "portal-card surface");
        card.append(node("h2", view[1]), node("p", "No connected records are displayed here until the authorized source is available."));
        const action = node("a", "Open " + view[1] + " →");
        action.href = "#" + view[0];
        card.append(action);
        cards.append(card);
      });
      content.append(cards);
      if (role === "customer") await renderShipments(content);
      return;
    }

    if (selected[0] === "shipments" && (role === "customer" || role === "enterprise" || role === "partner")) return renderShipments(content);
    if (selected[0] === "create" && role === "customer") return renderCreateRequest(content);
    if (selected[0] === "tracking") return content.append(emptyState("Live tracking not connected", "This workspace does not have a live tracking data source configured. Ask your KRIM contact for a verified update."));
    if (role === "field" && selected[0] === "assigned") return content.append(emptyState("Assigned work not connected", "Assigned tasks will appear here when an authorized backend source is available."));
    if (role === "field" && ["pickup-delivery", "events"].includes(selected[0])) return renderFieldUpdate(content);
    if (role === "field" && selected[0] === "proof") return renderProofOfDelivery(content);
    if (role === "field" && selected[0] === "queue") return renderQueue(content);
    content.append(emptyState("No connected data source", "This workspace section is ready for an authorized backend integration. No sample records or operational claims are shown."));
  }

  async function requireSession() {
    const result = await window.KRIM.auth.session();
    if (result.error) {
      content.replaceChildren(emptyState("Authentication unavailable", "The existing KRIM authentication service could not be reached."));
      return false;
    }
    if (!result.data || !result.data.session) {
      const returnPath = window.location.pathname + window.location.search + window.location.hash;
      const signIn = new URL("/app/sign-in.html", window.location.origin);
      signIn.searchParams.set("portal", role);
      signIn.searchParams.set("return", returnPath);
      window.location.replace(signIn.pathname + signIn.search);
      return false;
    }
    return true;
  }

  async function initialize() {
    await loadComponents();
    if (!await requireSession()) return;
    buildNavigation();
    window.addEventListener("krim:language-change", buildNavigation);
    appNav.addEventListener("click", (event) => {
      if (event.target.closest("a")) {
        sidebar.classList.remove("is-open");
        document.querySelector("[data-portal-menu]").setAttribute("aria-expanded", "false");
      }
    });
    window.addEventListener("hashchange", renderView);
    document.querySelector("[data-portal-menu]").addEventListener("click", (event) => {
      const button = event.currentTarget;
      const open = button.getAttribute("aria-expanded") !== "true";
      button.setAttribute("aria-expanded", String(open));
      sidebar.classList.toggle("is-open", open);
    });
    document.querySelector("[data-logout]").addEventListener("click", async () => {
      if (role === "field") await clearQueue();
      const { error } = await window.KRIM.auth.signOut();
      if (error) return notify("Sign out failed. Close this tab and contact your administrator.", "error");
      window.location.replace("/");
    });
    await renderView();
  }

  initialize().catch(() => {
    notificationRegion.replaceChildren(node("div", "Workspace could not be loaded. Please try again later.", "notice notice--error"));
  });

  function loadComponents() {
    if (window.KRIM_UI) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "/core/components/ui.js";
      script.onload = resolve;
      script.onerror = reject;
      document.head.append(script);
    });
  }
})();