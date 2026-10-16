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

const {
data: quote,
error: quoteError,
} = await supabase
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
.eq("status", "accepted")
.order("id", {
ascending: false,
})
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

if (currency !== "INR") {
return jsonResponse(
{
error:
"Current global Razorpay flow supports INR only",
},
400
);
}

const amountPaise =
Math.round(amount * 100);

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