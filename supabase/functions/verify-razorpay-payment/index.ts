import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
razorpay_payment_id
`)
.eq(
"razorpay_order_id",
razorpayOrderId
)
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
// --------------------------------------------------

if (
!paymentOrder.krim_shipment_id ||
!paymentOrder.krim_quote_id ||
!paymentOrder.partner_quote_id ||
!paymentOrder.customer_organization_id
) {
return jsonResponse(
{
error:
"This payment order is not linked to a global KRIM shipment",
},
400
);
}

// --------------------------------------------------
// User ownership
// --------------------------------------------------

if (
paymentOrder.customer_id &&
paymentOrder.customer_id !== user.id
) {
return jsonResponse(
{
error:
"Payment order does not belong to authenticated user",
},
403
);
}

// --------------------------------------------------
// Idempotency
// --------------------------------------------------

const alreadyPaid =
paymentOrder.status === "paid" &&
paymentOrder.razorpay_payment_id === razorpayPaymentId;

if (paymentOrder.status === "paid" && !alreadyPaid) {
return jsonResponse({
error: "This payment order is already paid by a different payment ID.",
},
409
);
}

// --------------------------------------------------
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

if (Math.round(Number(acceptedQuote.amount) * 100) !== Number(paymentOrder.amount_paise)
    || String(acceptedQuote.currency_code || "").toUpperCase() !== String(paymentOrder.currency || "").toUpperCase()) {
return jsonResponse({ error: "Payment order amount or currency does not match the accepted customer quote." }, 400);
}

const {
data: acceptedAssignment,
error: acceptedAssignmentError,
} = await supabase
.from("krim_shipment_partner_assignments")
.select("id, status, partner_quote_id")
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

// --------------------------------------------------
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

// --------------------------------------------------
// Mark payment order paid

const paidAt =
paymentOrder.paid_at || new Date().toISOString();

let updatedPaymentOrder: any = paymentOrder;

if (!alreadyPaid) {
const {
data: updatedPaymentOrderData,
error: updatePaymentError,
} = await supabase
.from("payment_orders")
.update({
status: "paid",
razorpay_payment_id: razorpayPaymentId,
razorpay_signature: razorpaySignature,
paid_at: paidAt,
failure_reason: null,
updated_at: paidAt,
})
.eq("id", paymentOrder.id)
.select("id, krim_shipment_id, krim_quote_id, partner_quote_id, customer_organization_id, amount_paise, currency, status, razorpay_order_id, razorpay_payment_id, paid_at")
.single();

if (updatePaymentError) {
console.error("Payment order update failed:", updatePaymentError);
return jsonResponse({ error: "Payment verified but KRIM payment record could not be updated" }, 500);
}

updatedPaymentOrder = updatedPaymentOrderData;
}

// Global financial transaction
// --------------------------------------------------

const {
data: existingTransaction,
error:
existingTransactionError,
} =
await supabase
.from(
"krim_financial_transactions"
)
.select("id")
.eq(
"provider",
"razorpay"
)
.eq(
"provider_reference",
razorpayPaymentId
)
.maybeSingle();

if (
existingTransactionError
) {
console.error(
"Financial transaction lookup error:",
existingTransactionError
);

return jsonResponse(
{
error:
"Payment verified but financial transaction check failed",
},
500
);
}

let financialTransactionId =
existingTransaction?.id ??
null;

if (!existingTransaction) {
const {
data: financialTransaction,
error:
financialTransactionError,
} =
await supabase
.from(
"krim_financial_transactions"
)
.insert({
shipment_id:
shipment.id,

organization_id:
shipment.customer_organization_id,

// FIX:
// Database constraint allows "payment",
// not "customer_payment".
transaction_type:
"payment",

amount:
Number(
paymentOrder.amount_paise
) / 100,

currency_code:
localCurrency,

provider:
"razorpay",

provider_reference:
razorpayPaymentId,

status:
"completed",

transaction_time:
paidAt,

metadata: {
payment_order_id:
paymentOrder.id,

razorpay_order_id:
razorpayOrderId,

razorpay_payment_id:
razorpayPaymentId,

krim_shipment_id:
shipment.id,

shipment_number:
shipment.shipment_number,

source:
"global_razorpay_verification",

krim_quote_id:
paymentOrder.krim_quote_id,

partner_quote_id:
paymentOrder.partner_quote_id,

customer_organization_id:
paymentOrder.customer_organization_id,
},
})
.select("id")
.single();

if (
financialTransactionError
) {
console.error(
"Financial transaction creation failed:",
financialTransactionError
);

return jsonResponse(
{
error:
"Payment verified but financial transaction creation failed",

payment_order_id:
updatedPaymentOrder.id,

razorpay_payment_id:
razorpayPaymentId,
},
500
);
}

financialTransactionId =
financialTransaction.id;
}

// --------------------------------------------------
// Final response
// --------------------------------------------------

return jsonResponse({
success: true,

verified: true,

already_verified: alreadyPaid && Boolean(existingTransaction),

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