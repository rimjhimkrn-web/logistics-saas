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

if (existingEvent) {
return jsonResponse({
success: true,
duplicate: true,
processed: existingEvent.processed,
});
}

/*
* Store the event before processing.
* This creates an audit trail.
*/
const { error: insertEventError } = await supabaseAdmin
.from("payment_webhook_events")
.insert({
event_id: razorpayEventId,
event_type: eventType,
payload: payload,
processed: false,
});

if (insertEventError) {
/*
* Another webhook request may have inserted the same event
* at almost exactly the same time.
*
* Because event_id is UNIQUE, treat duplicate insertion
* as already received.
*/
if (insertEventError.code === "23505") {
return jsonResponse({
success: true,
duplicate: true,
});
}

console.error(
"Could not store webhook event:",
insertEventError,
);

return jsonResponse(
{
success: false,
error: "Could not store webhook event",
},
500,
);
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
if (razorpayPaymentId) {
const failureReason =
paymentEntity?.error_description ||
paymentEntity?.error_reason ||
"Payment failed";

const { error: updateError } = await supabaseAdmin
.from("payment_orders")
.update({
status: "failed",
razorpay_payment_id: razorpayPaymentId,
failure_reason: failureReason,
})
.eq("razorpay_payment_id", razorpayPaymentId)
.neq("status", "paid");

if (updateError) {
console.error(
"Failed to update failed payment:",
updateError,
);

return jsonResponse(
{
success: false,
error: "Payment reconciliation failed",
},
500,
);
}
}
}

/*
* payment.captured
*/
if (
eventType === "payment.captured" ||
eventType === "order.paid"
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

/*
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

* Idempotent paid state.
*/
if (paymentOrder.status === "paid") {
await supabaseAdmin
.from("payment_webhook_events")
.update({
processed: true,
processed_at: new Date().toISOString(),
})
.eq("event_id", razorpayEventId);

return jsonResponse({
success: true,
already_paid: true,
});
}

/*
* Mark the payment as paid.
*/
const { error: updatePaymentError } =
await supabaseAdmin
.from("payment_orders")
.update({
status: "paid",
razorpay_payment_id:
razorpayPaymentId ||
paymentOrder.razorpay_payment_id,
paid_at: new Date().toISOString(),
failure_reason: null,
})
.eq("id", paymentOrder.id);

if (updatePaymentError) {
console.error(
"Failed to mark payment as paid:",
updatePaymentError,
);

return jsonResponse(
{
success: false,
error: "Could not reconcile payment",
},
500,
);
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