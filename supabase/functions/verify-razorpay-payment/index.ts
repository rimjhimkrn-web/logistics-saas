import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function currencyMinorUnitExponent(currency: string): number {
  const code = String(currency || "").trim().toUpperCase();
  if (["BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","UYI","VND","VUV","XAF","XOF","XPF"].includes(code)) return 0;
  if (["BHD","IQD","JOD","KWD","LYD","OMR","TND"].includes(code)) return 3;
  if (["CLF","UYW"].includes(code)) return 4;
  return 2;
}


const corsHeaders = {
"Access-Control-Allow-Origin": "*",
"Access-Control-Allow-Headers":
"authorization, x-client-info, apikey, content-type",
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

for (let i = 0; i < hex.length; i += 2) {
bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
}

return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
return Array.from(bytes)
.map((b) => b.toString(16).padStart(2, "0"))
.join("");
}

async function generateHmacSha256(
secret: string,
message: string
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
["sign"]
);

const signature = await crypto.subtle.sign(
"HMAC",
key,
encoder.encode(message)
);

return bytesToHex(new Uint8Array(signature));
}

function safeEqual(a: string, b: string): boolean {
if (a.length !== b.length) {
return false;
}

let result = 0;

for (let i = 0; i < a.length; i++) {
result |= a.charCodeAt(i) ^ b.charCodeAt(i);
}

return result === 0;
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
error: "Method not allowed",
},
405
);
}

try {
// --------------------------------------------------
// Environment
// --------------------------------------------------

const supabaseUrl =
Deno.env.get("SUPABASE_URL");

const serviceRoleKey =
Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const razorpayKeyId =
Deno.env.get("RAZORPAY_KEY_ID");

const razorpayKeySecret =
Deno.env.get("RAZORPAY_KEY_SECRET");

if (
!supabaseUrl ||
!serviceRoleKey ||
!razorpayKeyId ||
!razorpayKeySecret
) {
return jsonResponse(
{
error: "Server configuration incomplete",
},
500
);
}

// --------------------------------------------------
// Authenticate user
// --------------------------------------------------

const authHeader =
req.headers.get("Authorization");

if (
!authHeader ||
!authHeader.startsWith("Bearer ")
) {
return jsonResponse(
{
error: "Login required",
},
401
);
}

const token =
authHeader.substring(7).trim();

if (!token) {
return jsonResponse(
{
error: "Login required",
},
401
);
}

// --------------------------------------------------
// Service-role Supabase client
// --------------------------------------------------

const supabase =
createClient(
supabaseUrl,
serviceRoleKey
);

// --------------------------------------------------
// Verify Supabase user
// --------------------------------------------------

const {
data: userData,
error: userError,
} =
await supabase.auth.getUser(token);

if (
userError ||
!userData?.user
) {
console.error(
"Authentication error:",
userError
);

return jsonResponse(
{
error:
"Invalid or expired session",
},
401
);
}

const user =
userData.user;

// --------------------------------------------------
// Read request
// --------------------------------------------------

let body: any;

try {
body = await req.json();
} catch {
return jsonResponse(
{
error: "Invalid JSON body",
},
400
);
}

const razorpayPaymentId =
String(
body?.razorpay_payment_id || ""
).trim();

const razorpayOrderId =
String(
body?.razorpay_order_id || ""
).trim();

const razorpaySignature =
String(
body?.razorpay_signature || ""
).trim();

if (
!razorpayPaymentId ||
!razorpayOrderId ||
!razorpaySignature
) {
return jsonResponse(
{
error:
"Razorpay payment ID, order ID and signature are required",
},
400
);
}

// --------------------------------------------------
// Find local global payment order
// --------------------------------------------------

const {
data: paymentOrder,
error: paymentOrderError,
} =
await supabase
.from("payment_orders")
.select(`
id,
krim_shipment_id,
krim_quote_id,
partner_quote_id,
customer_organization_id,
customer_id,
amount_paise,
currency,
status,
razorpay_order_id,
razorpay_payment_id,
paid_at
`)
.eq(
"razorpay_order_id",
razorpayOrderId
)
.eq("payment_provider", "razorpay")
.maybeSingle();

if (paymentOrderError) {
console.error(
"Payment order lookup error:",
paymentOrderError
);

return jsonResponse(
{
error:
"Unable to find payment order",
},
500
);
}

if (!paymentOrder) {
return jsonResponse(
{
error:
"KRIM payment order not found",
},
404
);
}

// --------------------------------------------------
// Global payment only

if (!paymentOrder.krim_shipment_id) {
return jsonResponse(
{
error: "This payment order is not linked to a global KRIM shipment",
},
400
);
}

// User ownership

if (paymentOrder.customer_id && paymentOrder.customer_id !== user.id) {
return jsonResponse(
{
error: "Payment order does not belong to authenticated user",
},
403
);
}

// Idempotency and legacy compatibility

const alreadyPaid =
paymentOrder.status === "paid" &&
paymentOrder.razorpay_payment_id === razorpayPaymentId;

const legacyAlreadyPaid = alreadyPaid &&
(!paymentOrder.krim_quote_id || !paymentOrder.partner_quote_id || !paymentOrder.customer_organization_id);

if (paymentOrder.status === "paid" && !alreadyPaid) {
return jsonResponse(
{
error: "This payment order is already paid by a different payment ID.",
},
409
);
}

if (!legacyAlreadyPaid && (!paymentOrder.krim_quote_id || !paymentOrder.partner_quote_id || !paymentOrder.customer_organization_id)) {
return jsonResponse(
{
error: "This payment order is not bound to a partner-awarded customer quote.",
},
400
);
}

// Verify organization access through shipment
// --------------------------------------------------

const {
data: shipment,
error: shipmentError,
} =
await supabase
.from("krim_shipments")
.select(`
id,
shipment_number,
customer_organization_id,
status
`)
.eq(
"id",
paymentOrder.krim_shipment_id
)
.maybeSingle();

if (shipmentError) {
console.error(
"Shipment lookup error:",
shipmentError
);

return jsonResponse(
{
error:
"Unable to load global shipment",
},
500
);
}

if (!shipment) {
return jsonResponse(
{
error:
"Global shipment not found",
},
404
);
}

// A payment order can outlive its original checkout state. Re-check that the
// shipment is still confirmed immediately before accepting a new payment.
// Already-paid same-payment retries remain eligible for idempotent recovery.
if (!alreadyPaid && shipment.status !== "confirmed") {
  return jsonResponse({
    error: `Shipment is no longer confirmed. Current status: ${shipment.status}. Payment verification is blocked.`,
    code: "SHIPMENT_NOT_CONFIRMED",
  }, 409);
}

if (
!shipment.customer_organization_id
) {
return jsonResponse(
{
error:
"Shipment has no customer organization",
},
400
);
}

const {
data: hasOrgAccess,
error: accessError,
} =
await supabase.rpc(
"krim_has_organization_access",
{
p_user_id: user.id,
p_organization_id:
shipment.customer_organization_id,
}
);

if (accessError) {
console.error(
"Organization access error:",
accessError
);

return jsonResponse(
{
error:
"Authorization check failed",
},
500
);
}

if (!hasOrgAccess) {
return jsonResponse(
{
error:
"Organization access denied",
},
403
);
}

// --------------------------------------------------
// Verify the exact quote and accepted partner assignment
// --------------------------------------------------

if (!legacyAlreadyPaid) {
  // Verify the exact quote and accepted partner assignment
  // --------------------------------------------------
  
  if (paymentOrder.customer_organization_id !== shipment.customer_organization_id) {
  return jsonResponse({ error: "Payment order organization does not match the shipment." }, 403);
  }
  
  const {
  data: acceptedQuote,
  error: acceptedQuoteError,
  } = await supabase
  .from("krim_quotes")
  .select("id, shipment_id, customer_organization_id, partner_quote_id, amount, currency_code, status, valid_until")
  .eq("id", paymentOrder.krim_quote_id)
  .eq("shipment_id", shipment.id)
  .eq("customer_organization_id", shipment.customer_organization_id)
  .eq("partner_quote_id", paymentOrder.partner_quote_id)
  .maybeSingle();
  
  if (acceptedQuoteError) {
  console.error("Accepted quote verification lookup failed:", acceptedQuoteError);
  return jsonResponse({ error: "Unable to verify the accepted customer quote." }, 500);
  }
  
  if (!acceptedQuote || acceptedQuote.status !== "accepted") {
  return jsonResponse({ error: "The payment order is not bound to an accepted customer quote." }, 409);
  }
  
  if (acceptedQuote.valid_until && new Date(acceptedQuote.valid_until).getTime() <= Date.now()) {
  return jsonResponse({ error: "The accepted customer quote has expired." }, 409);
  }
  
  if (Math.round(Number(acceptedQuote.amount) * (10 ** currencyMinorUnitExponent(String(acceptedQuote.currency_code || "").toUpperCase()))) !== Number(paymentOrder.amount_paise)
      || String(acceptedQuote.currency_code || "").toUpperCase() !== String(paymentOrder.currency || "").toUpperCase()) {
  return jsonResponse({ error: "Payment order amount or currency does not match the accepted customer quote." }, 400);
  }
  
  const {
  data: acceptedAssignment,
  error: acceptedAssignmentError,
  } = await supabase
  .from("krim_shipment_partner_assignments")
  .select("id, status, partner_quote_id, partner_organization_id, shipment_leg_id, capacity_binding_id")
  .eq("shipment_id", shipment.id)
  .eq("partner_quote_id", acceptedQuote.partner_quote_id)
  .order("created_at", { ascending: false })
  .limit(1)
  .maybeSingle();
  
  if (acceptedAssignmentError) {
  console.error("Partner assignment verification lookup failed:", acceptedAssignmentError);
  return jsonResponse({ error: "Unable to verify partner assignment acceptance." }, 500);
  }
  
  if (!acceptedAssignment || acceptedAssignment.status !== "accepted") {
  return jsonResponse({ error: "Partner assignment is not accepted; payment verification is blocked." }, 409);
  }

  // Re-check the exact confirmed capacity reservation at verification time.
  // A previously-created order may outlive a released reservation.
  if (!acceptedAssignment.capacity_binding_id || !acceptedAssignment.shipment_leg_id) {
    return jsonResponse({ error: "The accepted partner assignment has no confirmed capacity binding. Payment verification is blocked.", code: "CAPACITY_RESERVATION_REQUIRED" }, 409);
  }

  const { data: capacityBinding, error: bindingError } = await supabase
    .from("krim_capacity_leg_bindings")
    .select("id, shipment_id, shipment_leg_id, reservation_id, status")
    .eq("id", acceptedAssignment.capacity_binding_id)
    .eq("shipment_id", shipment.id)
    .eq("shipment_leg_id", acceptedAssignment.shipment_leg_id)
    .eq("status", "confirmed")
    .maybeSingle();

  if (bindingError) {
    console.error("Capacity binding verification lookup failed:", bindingError);
    return jsonResponse({ error: "Unable to verify the confirmed capacity binding." }, 500);
  }

  if (!capacityBinding?.reservation_id) {
    return jsonResponse({ error: "A matching confirmed capacity binding is required before payment verification.", code: "CAPACITY_BINDING_NOT_CONFIRMED" }, 409);
  }

  const { data: capacityReservation, error: reservationError } = await supabase
    .from("krim_capacity_reservations")
    .select("id, organization_id, shipment_id, shipment_leg_id, status")
    .eq("id", capacityBinding.reservation_id)
    .eq("organization_id", acceptedAssignment.partner_organization_id)
    .eq("shipment_id", shipment.id)
    .eq("shipment_leg_id", acceptedAssignment.shipment_leg_id)
    .eq("status", "confirmed")
    .maybeSingle();

  if (reservationError) {
    console.error("Capacity reservation verification lookup failed:", reservationError);
    return jsonResponse({ error: "Unable to verify the confirmed capacity reservation." }, 500);
  }

  if (!capacityReservation) {
    return jsonResponse({ error: "The linked capacity reservation is missing, released or does not match this shipment and partner. Payment verification is blocked.", code: "CAPACITY_RESERVATION_NOT_CONFIRMED" }, 409);
  }
  
  // --------------------------------------------------
} else {
  // Legacy paid orders have no quote binding; only recover their idempotent financial record.
  // They cannot be used to create or verify a new payment.
  console.warn("Recovering an already-paid legacy order without quote binding:", paymentOrder.id);
}

// Verify Razorpay signature
// --------------------------------------------------

const signatureMessage =
`${razorpayOrderId}|${razorpayPaymentId}`;

const expectedSignature =
await generateHmacSha256(
razorpayKeySecret,
signatureMessage
);

if (
!safeEqual(
expectedSignature,
razorpaySignature
)
) {
console.error(
"Invalid Razorpay signature"
);

return jsonResponse(
{
error:
"Razorpay signature verification failed",
},
400
);
}

// --------------------------------------------------
// Verify payment directly with Razorpay
// --------------------------------------------------

const razorpayAuth =
btoa(
`${razorpayKeyId}:${razorpayKeySecret}`
);

const razorpayPaymentResponse =
await fetch(
`https://api.razorpay.com/v1/payments/${encodeURIComponent(
razorpayPaymentId
)}`,
{
method: "GET",
headers: {
Authorization:
`Basic ${razorpayAuth}`,
},
}
);

const razorpayPaymentText =
await razorpayPaymentResponse.text();

let razorpayPayment: any;

try {
razorpayPayment =
JSON.parse(
razorpayPaymentText
);
} catch {
razorpayPayment = {
raw: razorpayPaymentText,
};
}

if (
!razorpayPaymentResponse.ok
) {
console.error(
"Razorpay payment lookup failed:",
razorpayPayment
);

return jsonResponse(
{
error:
"Unable to verify payment with Razorpay",
},
502
);
}

// --------------------------------------------------
// Verify Razorpay order
// --------------------------------------------------

if (
razorpayPayment.order_id !==
razorpayOrderId
) {
return jsonResponse(
{
error:
"Razorpay payment/order mismatch",
},
400
);
}

// --------------------------------------------------
// Verify amount
// --------------------------------------------------

const razorpayAmount =
Number(
razorpayPayment.amount
);

const localAmount =
Number(
paymentOrder.amount_paise
);

if (
!Number.isFinite(
razorpayAmount
) ||
razorpayAmount !== localAmount
) {
return jsonResponse(
{
error:
"Payment amount mismatch",
},
400
);
}

// --------------------------------------------------
// Verify currency
// --------------------------------------------------

const razorpayCurrency =
String(
razorpayPayment.currency || ""
).toUpperCase();

const localCurrency =
String(
paymentOrder.currency || ""
).toUpperCase();

if (
razorpayCurrency !==
localCurrency
) {
return jsonResponse(
{
error:
"Payment currency mismatch",
},
400
);
}

// --------------------------------------------------
// Require captured payment
// --------------------------------------------------

const razorpayStatus =
String(
razorpayPayment.status || ""
).toLowerCase();

if (
razorpayStatus !== "captured"
) {
return jsonResponse(
{
error:
`Payment is not captured. Current Razorpay status: ${razorpayStatus}`,
},
400
);
}

// The database RPC owns the paid-state transition. Keep the provider
// signature/API verification above, but never write payment_orders.status
// directly from this Edge Function.
let updatedPaymentOrder: any = paymentOrder;

// Global financial transaction reconciliation
// --------------------------------------------------
// Use the same service-role-only, transactional and idempotent database
// reconciler as the signed webhook. Never acknowledge verification merely
// because a provider reference exists: the database validates the full
// shipment, quote, assignment, capacity, amount and currency binding.
if (legacyAlreadyPaid) {
  return jsonResponse({
    error: "This legacy paid order lacks the bindings required for automatic financial reconciliation. Manual review is required.",
    code: "LEGACY_PAYMENT_RECONCILIATION_REQUIRED",
    payment_order_id: paymentOrder.id,
  }, 409);
}

const {
  data: financialTransactionId,
  error: financialReconciliationError,
} = await supabase.rpc(
  "krim_internal_reconcile_razorpay_captured_payment",
  {
    p_payment_order_id: paymentOrder.id,
    p_razorpay_payment_id: razorpayPaymentId,
  },
);

if (financialReconciliationError || !financialTransactionId) {
  console.error(
    "Payment verified but atomic finance reconciliation failed:",
    financialReconciliationError,
  );
  return jsonResponse({
    error: "Payment verified but financial reconciliation is pending; retry required.",
    code: "PAYMENT_FINANCE_RECONCILIATION_PENDING",
    payment_order_id: updatedPaymentOrder.id,
    razorpay_payment_id: razorpayPaymentId,
  }, 500);
}

// Read back the committed row so the response reflects the canonical DB state.
const { data: committedPaymentOrder, error: committedOrderError } = await supabase
  .from("payment_orders")
  .select("id, krim_shipment_id, krim_quote_id, partner_quote_id, customer_organization_id, amount_paise, currency, status, razorpay_order_id, razorpay_payment_id, paid_at")
  .eq("id", paymentOrder.id)
  .maybeSingle();

if (committedOrderError || !committedPaymentOrder ||
    committedPaymentOrder.status !== "paid" ||
    committedPaymentOrder.razorpay_payment_id !== razorpayPaymentId) {
  console.error("Atomic payment committed but read-back verification failed:", committedOrderError);
  return jsonResponse({
    error: "Payment reconciliation committed but confirmation is pending; retry required.",
    code: "PAYMENT_COMMIT_READBACK_PENDING",
    payment_order_id: paymentOrder.id,
  }, 500);
}
updatedPaymentOrder = committedPaymentOrder;

// --------------------------------------------------

// Final response
// --------------------------------------------------

return jsonResponse({
success: true,

verified: true,

already_verified: alreadyPaid,

payment_order_id:
updatedPaymentOrder.id,

financial_transaction_id:
financialTransactionId,

krim_shipment_id:
shipment.id,

shipment_number:
shipment.shipment_number,

razorpay_order_id:
razorpayOrderId,

razorpay_payment_id:
razorpayPaymentId,

amount_paise:
updatedPaymentOrder.amount_paise,

currency:
updatedPaymentOrder.currency,

status:
"paid",

paid_at:
updatedPaymentOrder.paid_at,
});

} catch (error) {
console.error(
"Global Razorpay verification error:",
error
);

return jsonResponse(
{
error:
error instanceof Error
? error.message
: "Unexpected server error",
},
500
);
}
});