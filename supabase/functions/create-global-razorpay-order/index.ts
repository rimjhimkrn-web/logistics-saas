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

Deno.serve(async (req) => {
if (req.method === "OPTIONS") {
return new Response("ok", {
headers: corsHeaders,
});
}

if (req.method !== "POST") {
return jsonResponse(
{ error: "Method not allowed" },
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
error:
"Server configuration incomplete",
},
500
);
}

// --------------------------------------------------
// Authorization
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
// SERVICE-ROLE CLIENT
// --------------------------------------------------
// IMPORTANT:
// Do NOT attach the user's Authorization header
// globally to this client.
//
// This client performs the protected database
// operations after the user has been independently
// authenticated below.
// --------------------------------------------------

const supabase = createClient(
supabaseUrl,
serviceRoleKey
);

// --------------------------------------------------
// Verify authenticated user
// --------------------------------------------------

const {
data: userData,
error: userError,
} =
await supabase.auth.getUser(token);

if (userError || !userData?.user) {
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

const user = userData.user;

// --------------------------------------------------
// Request body
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

const shipmentId = Number(
body?.krim_shipment_id
);
const requestedQuoteId = body?.krim_quote_id == null || body?.krim_quote_id === ""
  ? null
  : Number(body.krim_quote_id);

if (
!Number.isInteger(shipmentId) ||
shipmentId <= 0
) {
return jsonResponse(
{
error:
"Valid krim_shipment_id is required",
},
400
);
}

// --------------------------------------------------
// Load shipment
// --------------------------------------------------

const {
data: shipment,
error: shipmentError,
} = await supabase
.from("krim_shipments")
.select(`
id,
shipment_number,
customer_organization_id,
status
`)
.eq("id", shipmentId)
.maybeSingle();

if (shipmentError) {
console.error(
"Shipment lookup error:",
shipmentError
);

return jsonResponse(
{
error:
"Unable to load shipment",
},
500
);
}

if (!shipment) {
return jsonResponse(
{
error: "Shipment not found",
},
404
);
}

// --------------------------------------------------
// Customer organization
// --------------------------------------------------

const organizationId =
shipment.customer_organization_id;

if (!organizationId) {
return jsonResponse(
{
error:
"Shipment has no customer organization",
},
400
);
}

// --------------------------------------------------
// Organization authorization
// --------------------------------------------------

const {
data: hasOrgAccess,
error: accessError,
} = await supabase.rpc(
"krim_has_organization_access",
{
p_user_id: user.id,
p_organization_id:
organizationId,
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
// Shipment state
// --------------------------------------------------

if (shipment.status !== "confirmed") {
return jsonResponse(
{
error:
`Shipment must be confirmed before payment. Current status: ${shipment.status}`,
},
400
);
}

// --------------------------------------------------
// Accepted quote
// --------------------------------------------------

if (requestedQuoteId !== null && (!Number.isInteger(requestedQuoteId) || requestedQuoteId <= 0)) {
return jsonResponse({ error: "Valid krim_quote_id is required when a quote is specified" }, 400);
}
let quoteQuery = supabase
.from("krim_quotes")
.select(`
id,
shipment_id,
customer_organization_id,
partner_quote_id,
amount,
currency_code,
valid_until,
status
`)
.eq("shipment_id", shipmentId)
.eq("customer_organization_id", organizationId)
.eq("status", "accepted");
if (requestedQuoteId !== null) quoteQuery = quoteQuery.eq("id", requestedQuoteId);
const {
data: quote,
error: quoteError,
} = await quoteQuery
.order("id", { ascending: false })
.limit(1)
.maybeSingle();

if (quoteError) {
console.error(
"Quote lookup error:",
quoteError
);

return jsonResponse(
{
error:
"Unable to load accepted quote",
},
500
);
}

if (!quote) {
return jsonResponse(
{
error:
"Accepted quote not found",
},
400
);
}

if (!quote.partner_quote_id) {
return jsonResponse(
{
error: "Partner selection is required before checkout. Please request partner bids and award a verified partner offer.",
},
409
);
}

const {
data: assignment,
error: assignmentError,
} = await supabase
.from("krim_shipment_partner_assignments")
.select("id, status, partner_quote_id")
.eq("shipment_id", shipmentId)
.eq("partner_quote_id", quote.partner_quote_id)
.order("created_at", { ascending: false })
.limit(1)
.maybeSingle();

if (assignmentError) {
console.error("Partner assignment lookup error:", assignmentError);
return jsonResponse({ error: "Unable to verify partner assignment acceptance" }, 500);
}

if (!assignment || assignment.status !== "accepted") {
return jsonResponse(
{
error: "The selected partner has not accepted the assignment yet. Payment remains locked.",
},
409
);
}

// --------------------------------------------------
// Quote organization check
// --------------------------------------------------

if (
quote.customer_organization_id !==
organizationId
) {
return jsonResponse(
{
error:
"Quote organization mismatch",
},
403
);
}

// --------------------------------------------------
// Quote expiry
// --------------------------------------------------

if (
quote.valid_until &&
new Date(
quote.valid_until
).getTime() <= Date.now()
) {
return jsonResponse(
{
error: "Quote has expired",
},
400
);
}

// --------------------------------------------------
// Amount
// --------------------------------------------------

const amount =
Number(quote.amount);

if (
!Number.isFinite(amount) ||
amount <= 0
) {
return jsonResponse(
{
error:
"Invalid quote amount",
},
400
);
}

const currency =
String(
quote.currency_code || ""
).toUpperCase();

// Server-authoritative capability registry. INR retains the existing
// checkout path. Any other currency requires explicit evidence-backed
// enablement for merchant eligibility, presentment, settlement, refunds and FX.
const { data: paymentCapability, error: capabilityError } = await supabase
.from("krim_payment_capability_registry")
.select("id,country_code,currency_code,provider_code,integration_status,checkout_enabled,merchant_eligibility_verified,presentment_supported,settlement_supported,refunds_supported,fx_supported")
.eq("country_code", "IN")
.eq("currency_code", currency)
.eq("provider_code", "razorpay")
.eq("integration_status", "implemented")
.eq("checkout_enabled", true)
.maybeSingle();

if (capabilityError || !paymentCapability) {
console.error("Payment capability gate blocked checkout", capabilityError);
return jsonResponse(
{
error: "No KRIM payment capability is enabled for this currency and provider.",
code: "PAYMENT_CAPABILITY_NOT_ENABLED",
},
503
);
}

const nonInrCurrencyVerified = currency === "INR" || (
paymentCapability.merchant_eligibility_verified === true &&
paymentCapability.presentment_supported === true &&
paymentCapability.settlement_supported === true &&
paymentCapability.refunds_supported === true &&
paymentCapability.fx_supported === true
);

if (!/^[A-Z]{3}$/.test(currency) || !nonInrCurrencyVerified) {
return jsonResponse(
{
error: "This currency is not enabled for KRIM checkout. International currency support requires verified merchant eligibility, presentment, settlement, refunds and FX.",
code: "PAYMENT_CURRENCY_NOT_VERIFIED",
},
503
);
}

const minorUnitFactor = 10 ** currencyMinorUnitExponent(currency);
const rawMinorUnits = amount * minorUnitFactor;
const amountPaise = Math.round(rawMinorUnits);
if (Math.abs(rawMinorUnits - amountPaise) > 1e-7) {
return jsonResponse(
{ error: "Quote amount exceeds the supported minor-unit precision for " + currency + ".", code: "CURRENCY_PRECISION_INVALID" },
400
);
}

if (amountPaise <= 0) {
return jsonResponse(
{
error:
"Invalid payment amount",
},
400
);
}

// --------------------------------------------------
// Existing payment order
// --------------------------------------------------

const {
data: existingOrder,
error: existingOrderError,
} = await supabase
.from("payment_orders")
.select(`
id,
krim_shipment_id,
krim_quote_id,
customer_organization_id,
amount_paise,
currency,
status,
razorpay_order_id
`)
.eq("krim_quote_id", quote.id)
.eq("customer_id", user.id)
.eq("customer_organization_id", organizationId)
.eq("payment_provider", "razorpay")
.in("status", [
"created",
"pending",
])
.order("created_at", {
ascending: false,
})
.limit(1)
.maybeSingle();

if (existingOrderError) {
console.error(
"Existing payment order lookup error:",
existingOrderError
);

return jsonResponse(
{
error:
"Unable to check existing payment order",
},
500
);
}

// --------------------------------------------------
// Reuse valid existing order
// --------------------------------------------------

if (
existingOrder &&
existingOrder.razorpay_order_id &&
Number(
existingOrder.amount_paise
) === amountPaise &&
String(
existingOrder.currency
).toUpperCase() === currency
) {
return jsonResponse({
success: true,
reused: true,
payment_order_id:
existingOrder.id,
razorpay_order_id: existingOrder.razorpay_order_id,
key_id: razorpayKeyId,
amount_paise:
amountPaise,
currency,
shipment_id:
shipment.id,
shipment_number:
shipment.shipment_number,
quote_id:
quote.id,
});
}

// --------------------------------------------------
// Create Razorpay order
// --------------------------------------------------

const receipt =
`krim_${shipment.id}_${quote.id}_${Date.now()}`;

const razorpayPayload = {
amount: amountPaise,
currency,
receipt,
notes: {
krim_shipment_id:
String(shipment.id),

krim_shipment_number:
String(
shipment.shipment_number
),

krim_quote_id:
String(quote.id),
},
};

const basicAuth =
btoa(
`${razorpayKeyId}:${razorpayKeySecret}`
);

console.log(
"Creating Razorpay order for shipment:",
shipment.id
);

const razorpayResponse =
await fetch(
"https://api.razorpay.com/v1/orders",
{
method: "POST",

headers: {
Authorization:
`Basic ${basicAuth}`,

"Content-Type":
"application/json",
},

body: JSON.stringify(
razorpayPayload
),
}
);

const razorpayText =
await razorpayResponse.text();

let razorpayData: any;

try {
razorpayData =
JSON.parse(
razorpayText
);
} catch {
razorpayData = {
raw: razorpayText,
};
}

// --------------------------------------------------
// Razorpay failure
// --------------------------------------------------

if (!razorpayResponse.ok) {
console.error(
"Razorpay order creation failed:",
JSON.stringify({
status:
razorpayResponse.status,

response:
razorpayData,
})
);

return jsonResponse(
{
error:
"Razorpay order creation failed",

razorpay_status:
razorpayResponse.status,

details:
razorpayData,
},
502
);
}

const razorpayOrderId =
razorpayData?.id;

if (!razorpayOrderId) {
console.error(
"Razorpay returned no order ID:",
razorpayData
);

return jsonResponse(
{
error:
"Razorpay returned an invalid order response",
},
502
);
}

// --------------------------------------------------
// Save local payment order
// --------------------------------------------------

const {
data: paymentOrder,
error: paymentInsertError,
} = await supabase
.from("payment_orders")
.insert({
shipment_id: null,
krim_shipment_id: shipment.id,
krim_quote_id: quote.id,
partner_quote_id: quote.partner_quote_id,
customer_organization_id: organizationId,
customer_id: user.id,
payment_provider: "razorpay",
amount_paise: amountPaise,
currency,
status: "created",
razorpay_order_id: razorpayOrderId,
})
.select(`
id,
krim_shipment_id,
krim_quote_id,
partner_quote_id,
customer_organization_id,
amount_paise,
currency,
status,
razorpay_order_id
`)
.single();

if (paymentInsertError) {
console.error(
"Local payment_orders insert failed:",
paymentInsertError
);

return jsonResponse(
{
error:
"Razorpay order created but local payment record failed",

razorpay_order_id:
razorpayOrderId,

database_error:
paymentInsertError.message,
},
500
);
}

// --------------------------------------------------
// Success
// --------------------------------------------------

return jsonResponse({
success: true,

reused: false,

payment_order_id:
paymentOrder.id,

razorpay_order_id: paymentOrder.razorpay_order_id,
key_id: razorpayKeyId,
amount_paise:
paymentOrder.amount_paise,

currency:
paymentOrder.currency,

shipment_id:
shipment.id,

shipment_number:
shipment.shipment_number,

quote_id:
quote.id,
});

} catch (error) {
console.error(
"Global Razorpay order function error:",
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