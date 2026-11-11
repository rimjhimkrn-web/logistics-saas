import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
"Access-Control-Allow-Origin": "*",
"Access-Control-Allow-Headers":
"authorization, x-client-info, apikey, content-type, x-razorpay-signature, x-razorpay-event-id",
"Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(data: unknown, status = 200) {
return new Response(JSON.stringify(data), {
status,
headers: {
...corsHeaders,
"Content-Type": "application/json",
},
});
}

function hexToBytes(hex: string): Uint8Array {
const bytes = new Uint8Array(hex.length / 2);

for (let i = 0; i < bytes.length; i++) {
bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
}

return bytes;
}

function safeEqual(a: Uint8Array, b: Uint8Array): boolean {
if (a.length !== b.length) return false;

let result = 0;

for (let i = 0; i < a.length; i++) {
result |= a[i] ^ b[i];
}

return result === 0;
}

async function generateSignature(
secret: string,
body: string,
): Promise<string> {
const encoder = new TextEncoder();

const key = await crypto.subtle.importKey(
"raw",
encoder.encode(secret),
{
name: "HMAC",
hash: "SHA-256",
},
false,
["sign"],
);

const signature = await crypto.subtle.sign(
"HMAC",
key,
encoder.encode(body),
);

return Array.from(new Uint8Array(signature))
.map((byte) => byte.toString(16).padStart(2, "0"))
.join("");
}

Deno.serve(async (req) => {
if (req.method === "OPTIONS") {
return new Response("ok", {
headers: corsHeaders,
});
}

if (req.method !== "POST") {
return jsonResponse(
{
success: false,
error: "Only POST requests are allowed",
},
405,
);
}

try {
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");

if (!supabaseUrl || !serviceRoleKey || !webhookSecret) {
console.error("Required server secrets are missing");

return jsonResponse(
{
success: false,
error: "Server configuration error",
},
500,
);
}

const razorpaySignature =
req.headers.get("x-razorpay-signature") || "";

const razorpayEventId =
req.headers.get("x-razorpay-event-id") || "";

if (!razorpaySignature) {
return jsonResponse(
{
success: false,
error: "Missing Razorpay signature",
},
401,
);
}

if (!razorpayEventId) {
return jsonResponse(
{
success: false,
error: "Missing Razorpay event ID",
},
400,
);
}

/*
* IMPORTANT:
* Read the raw request body.
* Razorpay webhook signatures are calculated from
* the exact raw request body.
*/
const rawBody = await req.text();

const expectedSignature = await generateSignature(
webhookSecret,
rawBody,
);

const receivedBytes = hexToBytes(razorpaySignature);
const expectedBytes = hexToBytes(expectedSignature);

if (!safeEqual(receivedBytes, expectedBytes)) {
console.error("Invalid Razorpay webhook signature");

return jsonResponse(
{
success: false,
error: "Invalid webhook signature",
},
401,
);
}

let payload: any;

try {
payload = JSON.parse(rawBody);
} catch {
return jsonResponse(
{
success: false,
error: "Invalid JSON payload",
},
400,
);
}

const eventType = payload?.event;

if (!eventType) {
return jsonResponse(
{
success: false,
error: "Missing webhook event type",
},
400,
);
}

// Explicitly allow only event types this handler actually reconciles.
// Unknown provider events are acknowledged as ignored, but are never recorded as processed.
const supportedEvents = new Set(["payment.failed", "payment.captured", "payment.authorized", "order.paid", "refund.created", "refund.processed", "refund.failed"]);
if (!supportedEvents.has(eventType)) {
console.warn("Ignoring unsupported Razorpay webhook event:", eventType);
return jsonResponse({ success: true, received: true, ignored: true, reason: "UNSUPPORTED_EVENT_TYPE" });
}

const supabaseAdmin = createClient(
supabaseUrl,
serviceRoleKey,
{
auth: {
autoRefreshToken: false,
persistSession: false,
},
},
);

/*
* Idempotency:
* Razorpay can retry the same webhook.
* The event ID lets KRIM process it only once.
*/
const { data: existingEvent, error: existingEventError } =
await supabaseAdmin
.from("payment_webhook_events")
.select("id, processed")
.eq("event_id", razorpayEventId)
.maybeSingle();

if (existingEventError) {
console.error(
"Could not check existing webhook event:",
existingEventError,
);

return jsonResponse(
{
success: false,
error: "Webhook event lookup failed",
},
500,
);
}

if (existingEvent?.processed) {
return jsonResponse({
success: true,
duplicate: true,
processed: true,
});
}

// Store new events before processing. If an earlier attempt left this event
// unprocessed, retry it instead of treating it as a completed duplicate.
if (!existingEvent) {
const { error: insertEventError } = await supabaseAdmin
.from("payment_webhook_events")
.insert({
event_id: razorpayEventId,
event_type: eventType,
payload: payload,
processed: false,
});

if (insertEventError) {
  // A concurrent delivery may have inserted the same event.
  if (insertEventError.code === "23505") {
    // Another delivery inserted the event concurrently. It may still be
    // processing or may fail before finalization. Do not acknowledge it as
    // successfully handled: return a retryable error so the provider retries.
    return jsonResponse({
      success: false,
      duplicate: true,
      processed: false,
      error: "Webhook event is already being processed; retry delivery",
    }, 409);
  }

  console.error("Could not store webhook event:", insertEventError);
  return jsonResponse({ success: false, error: "Could not store webhook event" }, 500);
}
}

/*
* Refund reconciliation. This records provider outcomes only; it never initiates a refund.
* Correlation is restricted to the KRIM request ID in Razorpay refund notes or an
* already-recorded provider refund ID. Amount, currency, and original payment are verified.
*/
if (eventType === "refund.created" || eventType === "refund.processed" || eventType === "refund.failed") {
  const refund = payload?.payload?.refund?.entity || null;
  const refundId = String(refund?.id || "").trim();
  const paymentId = String(refund?.payment_id || "").trim();
  const amount = Number(refund?.amount);
  const currency = String(refund?.currency || "").trim().toUpperCase();
  const noteRequestId = String(refund?.notes?.krim_refund_request_id || "").trim();
  if (!refundId || !paymentId || !Number.isSafeInteger(amount) || amount <= 0 || currency !== "INR") {
    return jsonResponse({ success: false, error: "Refund event is missing valid provider identifiers, amount, or INR currency" }, 400);
  }
  let refundQuery = supabaseAdmin.from("krim_refund_requests")
    .select("id,payment_order_id,amount_paise,status,reviewed_by,reviewer_organization_id,provider_refund_id")
    .limit(1);
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(noteRequestId)) {
    refundQuery = refundQuery.eq("id", noteRequestId);
  } else {
    refundQuery = refundQuery.eq("provider_refund_id", refundId);
  }
  const { data: refundRequest, error: refundLookupError } = await refundQuery.maybeSingle();
  if (refundLookupError) {
    console.error("Refund request lookup failed", refundLookupError);
    return jsonResponse({ success: false, error: "Refund request lookup failed" }, 500);
  }
  if (!refundRequest || !refundRequest.reviewed_by || !refundRequest.reviewer_organization_id) {
    return jsonResponse({ success: false, error: "No approved KRIM refund request matches this provider refund" }, 404);
  }
  const { data: originalPayment, error: originalPaymentError } = await supabaseAdmin
    .from("payment_orders")
    .select("id,razorpay_payment_id,amount_paise,currency,status,payment_provider,krim_shipment_id,customer_organization_id")
    .eq("id", refundRequest.payment_order_id)
    .maybeSingle();
  if (originalPaymentError) {
    console.error("Original payment lookup failed", originalPaymentError);
    return jsonResponse({ success: false, error: "Original payment lookup failed" }, 500);
  }
  if (!originalPayment || originalPayment.payment_provider !== "razorpay" ||
      originalPayment.razorpay_payment_id !== paymentId ||
      Number(originalPayment.amount_paise) !== amount || Number(refundRequest.amount_paise) !== amount ||
      String(originalPayment.currency).toUpperCase() !== currency) {
    return jsonResponse({ success: false, error: "Refund does not match the approved full-payment request", code: "REFUND_ORDER_MISMATCH" }, 409);
  }
  if (refundRequest.provider_refund_id && refundRequest.provider_refund_id !== refundId) {
    return jsonResponse({ success: false, error: "Conflicting provider refund ID; manual reconciliation required", code: "REFUND_ID_CONFLICT" }, 409);
  }
  const targetStatus = eventType === "refund.processed" ? "processed" : eventType === "refund.failed" ? "failed" : "execution_pending";
  const { error: refundUpdateError } = await supabaseAdmin.from("krim_refund_requests").update({
    provider_refund_id: refundId,
    provider_status: String(refund?.status || eventType).slice(0, 80),
    status: refundRequest.status === "processed" ? "processed" : targetStatus,
    processed_at: eventType === "refund.processed" ? new Date().toISOString() : undefined,
    failure_reason: eventType === "refund.failed" ? String(refund?.failure_reason || "Razorpay reported refund failure").slice(0, 1000) : null,
    updated_at: new Date().toISOString(),
  }).eq("id", refundRequest.id);
  if (refundUpdateError) {
    console.error("Refund request reconciliation update failed", refundUpdateError);
    return jsonResponse({ success: false, error: "Refund reconciliation update failed" }, 500);
  }
  const auditType = eventType === "refund.processed" ? "processed" : eventType === "refund.failed" ? "failed" : "execution_started";
  const { error: refundAuditError } = await supabaseAdmin.from("krim_refund_request_events").insert({
    refund_request_id: refundRequest.id,
    event_type: auditType,
    actor_user_id: refundRequest.reviewed_by,
    actor_organization_id: refundRequest.reviewer_organization_id,
    event_note: "Razorpay refund webhook reconciled; provider event signature verified.",
    event_data: { provider: "razorpay", provider_refund_id: refundId, provider_event_id: razorpayEventId, provider_event_type: eventType, provider_status: refund?.status || null },
  });
  if (refundAuditError) {
    console.error("Refund audit event insert failed", refundAuditError);
    return jsonResponse({ success: false, error: "Refund audit recording failed" }, 500);
  }
  if (eventType === "refund.processed") {
    const { data: changedOrder, error: paymentStatusError } = await supabaseAdmin.from("payment_orders")
      .update({ status: "refunded", updated_at: new Date().toISOString() })
      .eq("id", originalPayment.id).eq("status", "paid").select("id").maybeSingle();
    if (paymentStatusError) {
      console.error("Payment order refund status update failed", paymentStatusError);
      return jsonResponse({ success: false, error: "Payment order refund status update failed" }, 500);
    }
    if (!changedOrder && originalPayment.status !== "refunded") {
      return jsonResponse({ success: false, error: "Payment order state conflicts with processed refund", code: "REFUND_PAYMENT_STATE_CONFLICT" }, 409);
    }

    // Record the completed refund as a debit in the KRIM financial ledger.
    // The provider refund ID is the idempotency anchor across webhook retries.
    if (!originalPayment.krim_shipment_id || !originalPayment.customer_organization_id) {
      return jsonResponse({ success: false, error: "Refund payment is missing its KRIM shipment or customer organization binding", code: "REFUND_LEDGER_BINDING_MISSING" }, 409);
    }
    const refundAmount = amount / 100;
    const expectedLedger = {
      shipment_id: originalPayment.krim_shipment_id,
      organization_id: originalPayment.customer_organization_id,
      transaction_type: "refund",
      amount: refundAmount,
      currency_code: "INR",
      provider: "razorpay",
      provider_reference: refundId,
      status: "completed",
      direction: "debit",
      ownership_scope: "company",
    };
    const { data: existingRefundLedger, error: refundLedgerLookupError } = await supabaseAdmin
      .from("krim_financial_transactions")
      .select("id,shipment_id,organization_id,transaction_type,amount,currency_code,provider,provider_reference,status,direction,ownership_scope")
      .eq("provider", "razorpay")
      .eq("provider_reference", refundId)
      .maybeSingle();
    if (refundLedgerLookupError) {
      console.error("Refund ledger lookup failed", refundLedgerLookupError);
      return jsonResponse({ success: false, error: "Refund ledger lookup failed; retry required" }, 500);
    }
    if (existingRefundLedger) {
      const matches = existingRefundLedger.shipment_id === expectedLedger.shipment_id &&
        existingRefundLedger.organization_id === expectedLedger.organization_id &&
        existingRefundLedger.transaction_type === expectedLedger.transaction_type &&
        Number(existingRefundLedger.amount) === expectedLedger.amount &&
        String(existingRefundLedger.currency_code).toUpperCase() === "INR" &&
        existingRefundLedger.provider === "razorpay" &&
        existingRefundLedger.provider_reference === refundId &&
        existingRefundLedger.status === "completed" &&
        existingRefundLedger.direction === "debit" &&
        existingRefundLedger.ownership_scope === "company";
      if (!matches) {
        console.error("Existing refund ledger entry conflicts with verified Razorpay refund", { refundId });
        return jsonResponse({ success: false, error: "Existing refund ledger entry conflicts; manual reconciliation required", code: "REFUND_LEDGER_CONFLICT" }, 409);
      }
    } else {
      const { error: refundLedgerInsertError } = await supabaseAdmin
        .from("krim_financial_transactions")
        .insert({
          ...expectedLedger,
          transaction_time: new Date().toISOString(),
          source_reference: "payment_order:" + originalPayment.id,
          idempotency_key: "razorpay_refund:" + refundId,
          metadata: {
            payment_order_id: originalPayment.id,
            razorpay_payment_id: paymentId,
            razorpay_refund_id: refundId,
            refund_request_id: refundRequest.id,
            provider_event_id: razorpayEventId,
            provider_event_type: eventType,
            source: "razorpay_refund_webhook_reconciliation",
          },
        });
      if (refundLedgerInsertError) {
        // A concurrent webhook may have inserted the same provider refund.
        if (refundLedgerInsertError.code !== "23505") {
          console.error("Refund ledger insert failed", refundLedgerInsertError);
          return jsonResponse({ success: false, error: "Refund ledger recording failed; retry required" }, 500);
        }
        const { data: concurrentLedger, error: concurrentLedgerError } = await supabaseAdmin
          .from("krim_financial_transactions")
          .select("id,shipment_id,organization_id,transaction_type,amount,currency_code,provider,provider_reference,status,direction,ownership_scope")
          .eq("provider", "razorpay")
          .eq("provider_reference", refundId)
          .maybeSingle();
        if (concurrentLedgerError || !concurrentLedger ||
            concurrentLedger.shipment_id !== expectedLedger.shipment_id ||
            concurrentLedger.organization_id !== expectedLedger.organization_id ||
            concurrentLedger.transaction_type !== "refund" ||
            Number(concurrentLedger.amount) !== refundAmount ||
            String(concurrentLedger.currency_code).toUpperCase() !== "INR" ||
            concurrentLedger.status !== "completed" ||
            concurrentLedger.direction !== "debit" ||
            concurrentLedger.ownership_scope !== "company") {
          console.error("Concurrent refund ledger insert could not be verified", concurrentLedgerError);
          return jsonResponse({ success: false, error: "Concurrent refund ledger conflict; manual reconciliation required", code: "REFUND_LEDGER_CONFLICT" }, 409);
        }
      }
    }
  }
  const { error: finalizeRefundWebhookError } = await supabaseAdmin.from("payment_webhook_events")
    .update({ processed: true, processed_at: new Date().toISOString() }).eq("event_id", razorpayEventId);
  if (finalizeRefundWebhookError) {
    console.error("Refund webhook finalization failed", finalizeRefundWebhookError);
    return jsonResponse({ success: false, error: "Refund webhook finalization failed" }, 500);
  }
  return jsonResponse({ success: true, received: true, refund_reconciled: true, event: eventType });
}

/*
* Extract payment/order information.
*/
const paymentEntity =
payload?.payload?.payment?.entity || null;

const orderEntity =
payload?.payload?.order?.entity || null;

const razorpayPaymentId =
paymentEntity?.id || null;

const razorpayOrderId =
paymentEntity?.order_id ||
orderEntity?.id ||
null;

/*
* payment.failed
*/
if (eventType === "payment.failed") {
if (!razorpayOrderId || !razorpayPaymentId) {
return jsonResponse({
success: false,
error: "Failed-payment event is missing its payment or order ID",
}, 400);
}
const failureReason =
paymentEntity?.error_description ||
paymentEntity?.error_reason ||
"Payment failed";

// A failed attempt often has a new payment ID that is not yet stored on the
// KRIM order. Resolve the canonical order by the provider order ID instead.
// Never downgrade an order already marked paid.
const { data: failedOrder, error: failedOrderLookupError } = await supabaseAdmin
.from("payment_orders")
.select("id, status, razorpay_payment_id")
.eq("razorpay_order_id", razorpayOrderId)
.maybeSingle();

if (failedOrderLookupError) {
console.error("Failed-payment order lookup failed:", failedOrderLookupError);
return jsonResponse({ success: false, error: "Payment reconciliation failed" }, 500);
}
if (!failedOrder) {
return jsonResponse({ success: false, error: "KRIM payment order not found" }, 404);
}
if (failedOrder.status !== "paid") {
const { error: updateError } = await supabaseAdmin
.from("payment_orders")
.update({
status: "failed",
razorpay_payment_id: razorpayPaymentId,
failure_reason: failureReason,
})
.eq("id", failedOrder.id)
.neq("status", "paid");

if (updateError) {
console.error("Failed to update failed payment:", updateError);
return jsonResponse({ success: false, error: "Payment reconciliation failed" }, 500);
}
}
}

/*
* payment.captured
*/
if (
eventType === "payment.captured" || eventType === "order.paid"
) {
if (!razorpayOrderId) {
console.error("Webhook has no Razorpay order ID");

return jsonResponse(
{
success: false,
error: "Missing Razorpay order ID",
},
400,
);
}

/*
* Find the KRIM payment order using the
* server-stored Razorpay order ID.
*/
const { data: paymentOrder, error: paymentOrderError } =
await supabaseAdmin
.from("payment_orders")
.select(
"id, status, razorpay_order_id, razorpay_payment_id, amount_paise, currency",
)
.eq("razorpay_order_id", razorpayOrderId)
.maybeSingle();

if (paymentOrderError) {
console.error(
"Payment order lookup failed:",
paymentOrderError,
);

return jsonResponse(
{
success: false,
error: "Payment order lookup failed",
},
500,
);
}

/*
* If Razorpay knows about a payment but KRIM does not,
* don't blindly create a payment record.
*/
if (!paymentOrder) {
console.error(
"No KRIM payment order found for Razorpay order:",
razorpayOrderId,
);

return jsonResponse(
{
success: false,
error: "KRIM payment order not found",
},
404,
);
}

// Fail closed unless the signed provider event matches the exact KRIM order amount,
// currency, payment ID, and captured state. A valid webhook signature alone does not
// prove that this is the amount/currency expected by this specific KRIM payment order.
const webhookAmount = Number(paymentEntity?.amount);
const expectedAmount = Number(paymentOrder.amount_paise);
const webhookCurrency = String(paymentEntity?.currency || "").trim().toUpperCase();
const expectedCurrency = String(paymentOrder.currency || "").trim().toUpperCase();
const webhookPaymentStatus = String(paymentEntity?.status || "").trim().toLowerCase();
if (
  !razorpayPaymentId ||
  !Number.isSafeInteger(webhookAmount) ||
  webhookAmount <= 0 ||
  webhookAmount !== expectedAmount ||
  !webhookCurrency ||
  webhookCurrency !== expectedCurrency ||
  webhookPaymentStatus !== "captured"
) {
  console.error("Razorpay webhook payment does not match the canonical KRIM order.");
  return jsonResponse({
    success: false,
    error: "Payment amount, currency, payment ID, or captured status does not match the KRIM order",
    code: "PAYMENT_ORDER_MISMATCH",
  }, 409);
}

// Idempotency must bind an already-paid order to the same provider payment ID.
if (paymentOrder.status === "paid") {
const { data: duplicateFinanceId, error: duplicateFinanceError } = await supabaseAdmin.rpc(
  "krim_internal_reconcile_razorpay_captured_payment",
  { p_payment_order_id: paymentOrder.id, p_razorpay_payment_id: razorpayPaymentId },
);
if (duplicateFinanceError || !duplicateFinanceId) {
  console.error("Paid duplicate webhook finance reconciliation failed.", duplicateFinanceError);
  return jsonResponse({ success: false, error: "Payment finance reconciliation is pending; retry required", code: "PAYMENT_FINANCE_RECONCILIATION_PENDING" }, 500);
}
if (paymentOrder.razorpay_payment_id !== razorpayPaymentId) {
console.error("Conflicting captured payment for an already-paid KRIM order.", {
orderId: paymentOrder.id,
hasStoredPaymentId: Boolean(paymentOrder.razorpay_payment_id),
});
return jsonResponse({
success: false,
error: "This KRIM order is already paid by a different payment ID; manual reconciliation is required.",
code: "PAYMENT_ID_CONFLICT",
}, 409);
}

const { error: duplicateFinalizeError } = await supabaseAdmin
.from("payment_webhook_events")
.update({ processed: true, processed_at: new Date().toISOString() })
.eq("event_id", razorpayEventId);

if (duplicateFinalizeError) {
console.error("Could not finalize matching duplicate webhook.", duplicateFinalizeError);
return jsonResponse({ success: false, error: "Webhook processing finalization failed" }, 500);
}

return jsonResponse({ success: true, already_paid: true, duplicate_payment: true });
}

/*
* Conditional paid-state transition. Only the observed prior state may transition.
* The returned row lets us detect concurrent deliveries instead of overwriting them.
*/
const { data: paidOrder, error: updatePaymentError } = await supabaseAdmin
.from("payment_orders")
.update({
status: "paid",
razorpay_payment_id: razorpayPaymentId,
paid_at: new Date().toISOString(),
failure_reason: null,
})
.eq("id", paymentOrder.id)
.eq("status", paymentOrder.status)
.select("id, status, razorpay_payment_id")
.maybeSingle();

if (updatePaymentError) {
console.error("Failed to mark payment as paid:", updatePaymentError);
return jsonResponse({ success: false, error: "Could not reconcile payment" }, 500);
}

if (!paidOrder) {
const { data: currentOrder, error: currentOrderError } = await supabaseAdmin
.from("payment_orders")
.select("id, status, razorpay_payment_id")
.eq("id", paymentOrder.id)
.maybeSingle();

if (currentOrderError) {
console.error("Could not verify concurrent payment reconciliation.", currentOrderError);
return jsonResponse({ success: false, error: "Could not verify payment reconciliation" }, 500);
}

if (currentOrder?.status !== "paid" || currentOrder.razorpay_payment_id !== razorpayPaymentId) {
return jsonResponse({
success: false,
error: "Payment order changed during reconciliation; manual review may be required.",
code: "PAYMENT_RECONCILIATION_CONFLICT",
}, 409);
}
}
}

// Do not acknowledge captured-payment events until the matching financial
// transaction exists. The RPC is transactional and idempotent.
if (eventType === "payment.captured" || eventType === "order.paid") {
  const { data: financeTransactionId, error: financeReconciliationError } = await supabaseAdmin.rpc(
    "krim_internal_reconcile_razorpay_captured_payment",
    { p_payment_order_id: paymentOrder.id, p_razorpay_payment_id: razorpayPaymentId },
  );
  if (financeReconciliationError || !financeTransactionId) {
    console.error("Payment finance reconciliation failed; event remains retryable.", financeReconciliationError);
    return jsonResponse({
      success: false,
      error: "Payment confirmed but finance reconciliation is pending; retry required",
      code: "PAYMENT_FINANCE_RECONCILIATION_PENDING",
    }, 500);
  }
}

/*
* payment.authorized:
* We intentionally do not mark the order as PAID here.
* Captured/order.paid is the authoritative paid state
* for this reconciliation flow.
*/
if (eventType === "payment.authorized") {
console.log(
"Payment authorized:",
razorpayPaymentId,
);
}

/*
* Mark webhook event as successfully processed.
*/
const { error: processedError } =
await supabaseAdmin
.from("payment_webhook_events")
.update({
processed: true,
processed_at: new Date().toISOString(),
})
.eq("event_id", razorpayEventId);

if (processedError) {
console.error(
"Could not mark webhook as processed:",
processedError,
);

return jsonResponse(
{
success: false,
error: "Webhook processing finalization failed",
},
500,
);
}

return jsonResponse({
success: true,
received: true,
event: eventType,
});
} catch (error) {
console.error("Webhook error:", error);

return jsonResponse(
{
success: false,
error: "Internal webhook processing error",
},
500,
);
}
});