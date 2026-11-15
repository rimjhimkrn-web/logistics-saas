/**
 * KRIM Support Runtime
 * Customer ticket creation and history use the authenticated Supabase support backend.
 * Remaining legacy support utilities explicitly remain informational/local prototypes.
 */
(function () {
  "use strict";
  const $ = id => document.getElementById(id);
  const form = $("support-form");
  const result = $("support-result") || $("ticket-result");
  const page = document.body.dataset.supportPage || "";
  const say = message => { if (result) result.textContent = message; };
  const safe = value => String(value || "").trim();
  const client = window.KRIM_SUPABASE || window.supabaseClient;

  async function requireSession() {
    if (!client) throw new Error("KRIM backend configuration did not load. Refresh and retry.");
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    if (!data?.session) {
      location.href = "../../auth/login.html?role=customer&next=" + encodeURIComponent(location.pathname + location.search);
      return null;
    }
    return data.session;
  }

  if (page === "create-ticket" && form) {
    form.addEventListener("submit", async event => {
      event.preventDefault();
      const button = form.querySelector('button[type="submit"]');
      if (button.disabled) return;
      const data = Object.fromEntries(new FormData(form).entries());
      const subject = safe(data.subject);
      const message = safe(data.description);
      if (!subject || subject.length > 160 || !message || message.length > 8000) {
        say("Enter a subject (maximum 160 characters) and details (maximum 8,000 characters).");
        return;
      }
      button.disabled = true;
      say("Submitting your ticket securely to KRIM Support…");
      try {
        const session = await requireSession();
        if (!session) return;
        const categoryMap = {
          "Shipment delay": "shipment",
          "Account access": "general",
          "Documentation": "other",
          "Payment or invoice": "payment",
          "Partner coordination": "partner",
          "Technical issue": "technical",
          "Other": "other"
        };
        const priorityMap = {
          "P3 — Standard": "normal",
          "P2 — High": "high",
          "P1 — Critical": "urgent"
        };
        const reference = safe(data.shipmentRef);
        const { data: ticket, error } = await client.from("support_tickets").insert({
          user_id: session.user.id,
          category: categoryMap[data.category] || "general",
          subject,
          message,
          priority: priorityMap[data.priority] || "normal",
          tracking_number: reference || null
        }).select("id,ticket_number,status,created_at").single();
        if (error) throw error;
        form.reset();
        say("Ticket submitted successfully. Reference: " + (ticket.ticket_number || ("#" + ticket.id)) +
          "\nStatus: " + (ticket.status || "open") +
          "\nCreated: " + new Date(ticket.created_at).toLocaleString() +
          "\nYour request is now recorded in KRIM Support. Keep this reference for follow-up.");
      } catch (error) {
        say("Ticket was not confirmed as submitted: " + (error?.message || "Unknown error") +
          ". Please sign in and retry. If you are unsure whether it was saved, check Ticket History first.");
      } finally {
        button.disabled = false;
      }
    });
    return;
  }

  if (page === "ticket-history" && form) {
    async function loadHistory(status) {
      const button = form.querySelector('button[type="submit"]');
      button.disabled = true;
      say("Loading your secure ticket history and customer-visible replies…");
      try {
        const session = await requireSession();
        if (!session) return;
        let query = client.from("support_tickets")
          .select("id,ticket_number,category,subject,message,status,priority,created_at,updated_at")
          .eq("user_id", session.user.id)
          .order("created_at", { ascending: false })
          .limit(100);
        if (status) query = query.eq("status", status);
        const { data, error } = await query;
        if (error) throw error;
        const rows = data || [];
        const root = $("ticket-result");
        root.replaceChildren();
        if (!rows.length) {
          root.textContent = "No support tickets found for this account and filter.";
        } else {
          const ids = rows.map(ticket => ticket.id);
          const { data: messageRows, error: messageError } = await client
            .from("krim_support_ticket_messages")
            .select("id,ticket_id,sender_user_id,message_type,body,created_at")
            .in("ticket_id", ids)
            .eq("is_internal", false)
            .order("created_at", { ascending: true });
          if (messageError) throw messageError;
          const byTicket = new Map();
          (messageRows || []).forEach(message => {
            const list = byTicket.get(String(message.ticket_id)) || [];
            list.push(message);
            byTicket.set(String(message.ticket_id), list);
          });
          rows.forEach(ticket => {
            const card = document.createElement("article");
            card.style.cssText = "border:1px solid #dbe4ef;border-radius:14px;padding:16px;margin:14px 0;background:#fff";
            const heading = document.createElement("h3");
            heading.textContent = (ticket.ticket_number || ("Ticket #" + ticket.id)) + " · " + ticket.subject;
            const meta = document.createElement("p");
            meta.textContent = "Status: " + ticket.status + " · Priority: " + ticket.priority + " · Created: " + new Date(ticket.created_at).toLocaleString();
            const issueTitle = document.createElement("strong");
            issueTitle.textContent = "Original request";
            const issue = document.createElement("p");
            issue.textContent = ticket.message;
            card.append(heading, meta, issueTitle, issue);

            const threadTitle = document.createElement("h4");
            threadTitle.textContent = "Conversation";
            threadTitle.style.cssText = "margin:16px 0 8px;color:#0f2b46";
            card.appendChild(threadTitle);
            const messages = byTicket.get(String(ticket.id)) || [];
            if (!messages.length) {
              const empty = document.createElement("p");
              empty.textContent = "No customer-visible response has been recorded yet.";
              empty.style.color = "#64748b";
              card.appendChild(empty);
            } else {
              messages.forEach(message => {
                const item = document.createElement("div");
                item.style.cssText = "border:1px solid #e2e8f0;border-radius:10px;padding:11px;margin:8px 0;background:#f8fafc";
                const who = document.createElement("strong");
                who.textContent = message.sender_user_id === session.user.id ? "You" : "KRIM Support";
                const when = document.createElement("small");
                when.textContent = " · " + new Date(message.created_at).toLocaleString();
                const body = document.createElement("p");
                body.textContent = message.body;
                body.style.cssText = "margin:8px 0 0;white-space:pre-wrap;overflow-wrap:anywhere";
                const label = document.createElement("div");
                label.append(who, when);
                item.append(label, body);
                card.appendChild(item);
              });
            }

            if (["open", "in_progress"].includes(String(ticket.status).toLowerCase())) {
              const replyForm = document.createElement("form");
              replyForm.style.cssText = "display:grid;gap:10px;margin-top:14px";
              const label = document.createElement("label");
              label.textContent = "Reply to KRIM Support";
              label.style.fontWeight = "700";
              const input = document.createElement("textarea");
              input.required = true;
              input.maxLength = 5000;
              input.rows = 3;
              input.placeholder = "Add relevant information or respond to the support team.";
              input.style.cssText = "width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:10px;padding:12px;font:inherit";
              label.appendChild(input);
              const send = document.createElement("button");
              send.type = "submit";
              send.textContent = "Send reply";
              const replyStatus = document.createElement("p");
              replyStatus.setAttribute("role", "status");
              replyStatus.setAttribute("aria-live", "polite");
              replyForm.append(label, send, replyStatus);
              replyForm.addEventListener("submit", async event => {
                event.preventDefault();
                const body = input.value.trim();
                if (body.length < 2 || body.length > 5000) {
                  replyStatus.textContent = "Reply must contain 2–5,000 characters.";
                  return;
                }
                send.disabled = true;
                replyStatus.textContent = "Sending your reply securely…";
                try {
                  const { data: reply, error: replyError } = await client.rpc("krim_customer_reply_support_ticket", {
                    p_ticket_id: ticket.id,
                    p_body: body
                  });
                  if (replyError) throw replyError;
                  if (!reply?.success) throw new Error("KRIM did not confirm the reply.");
                  await loadHistory(status);
                  say("Your reply was saved to the ticket conversation.");
                } catch (replyError) {
                  replyStatus.textContent = "Reply was not confirmed: " + (replyError?.message || "Please retry.");
                  send.disabled = false;
                }
              });
              card.appendChild(replyForm);
            } else {
              const closed = document.createElement("p");
              closed.textContent = "This ticket is " + ticket.status + ". Create a new ticket if you need help with a separate issue.";
              closed.style.color = "#64748b";
              card.appendChild(closed);
            }
            root.appendChild(card);
          });
        }
        say("Loaded " + rows.length + " ticket(s) and their customer-visible conversation history.");
      } catch (error) {
        say("Ticket history could not be loaded: " + (error?.message || "Unknown error"));
      } finally {
        button.disabled = false;
      }
    }
    form.addEventListener("submit", event => {
      event.preventDefault();
      loadHistory(safe(new FormData(form).get("status")));
    });
    loadHistory("");
    return;
  }

  // Legacy informational tools remain non-transactional until their own workflows are connected.
  const STORAGE_KEY = "krim_support_records_v1";
  const readRecords = () => { try { const v = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]"); return Array.isArray(v) ? v : []; } catch (_) { return []; } };
  const writeRecords = rows => localStorage.setItem(STORAGE_KEY, JSON.stringify(rows));
  const format = r => ["Reference: " + r.id, "Type: " + r.type, "Status: " + r.status, "Created: " + r.createdAt, "Subject: " + r.subject, r.description || ""].filter(Boolean).join("\n");
  if (!form) return;
  form.addEventListener("submit", event => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form).entries());
    const rows = readRecords();
    if (page === "ticket-history") { say("This browser-only history is retired. Use the secure Ticket History page."); return; }
    if (page === "service-status") { say("Live monitoring is not connected; no current uptime or incident state can be verified."); return; }
    if (page === "ticket-details" || page === "priority-escalation" || page === "resolution-confirmation") {
      say("This legacy workflow is not connected to the live support backend. Use Ticket History to review submitted tickets; contact KRIM Support for escalation.");
      return;
    }
    say("This support tool is informational only and is not connected to a live operational workflow. Create a Support Ticket to contact KRIM Support.");
  });
})();
