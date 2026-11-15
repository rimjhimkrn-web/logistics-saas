import { createClient } from "npm:@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Cache-Control":"no-store","Content-Type":"application/json"};
function reply(status:number,body:Record<string,unknown>){return new Response(JSON.stringify(body),{status,headers:cors});}
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CONSENT_NOTICE_VERSION = "2026-11-15-v1";
const CONSENT_NOTICE_LANGUAGE = "en-IN";
const CONSENT_NOTICE_APPROVED = false;
const CONSENT_NOTICE_TEXT = "KRIM Driver location sharing (draft notice — GPS remains disabled): If and when KRIM enables this feature after publishing an approved GPS retention period, deletion process and legal-hold terms, this app will share this device location only for the shipment assignment selected by you and marked In Transit. Location may be visible to KRIM operations personnel and the customer/shipper authorized for that shipment. You may decline or stop sharing at any time. Android background sharing requires location permission and an ongoing location notification; if background permission is not granted, only foreground sharing can operate. Location can be delayed or interrupted by device, battery, GPS or network conditions. Do not use the phone while driving. KRIM location tracking is not emergency monitoring or safety-critical navigation. This draft notice is not approved for commercial use. GPS collection remains disabled until the approved notice and retention terms are published and the legal launch gate is opened.";
async function sha256Hex(value:string):Promise<string>{
 const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
 return Array.from(new Uint8Array(digest)).map(byte=>byte.toString(16).padStart(2,"0")).join("");
}
const gpsLaunchApproved = Deno.env.get("KRIM_GPS_TRACKING_ENABLED") === "true"
 && Deno.env.get("KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION") === "2026-11-15-v1";

Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 const authorization=req.headers.get("Authorization")||"";
 const token=authorization.toLowerCase().startsWith("bearer ")?authorization.slice(7).trim():authorization.trim();
 if(!token)return reply(401,{error:"Authentication required"});
 const url=Deno.env.get("SUPABASE_URL"),publishableKey=Deno.env.get("SUPABASE_ANON_KEY")||Deno.env.get("SUPABASE_PUBLISHABLE_KEY"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!publishableKey||!serviceKey)return reply(503,{error:"Tracking service is not configured"});
 const authClient=createClient(url,publishableKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:authData,error:authError}=await authClient.auth.getUser(token);
 if(authError||!authData.user)return reply(401,{error:"Session is invalid or expired"});
 let body:Record<string,unknown>;try{body=await req.json()}catch{return reply(400,{error:"Invalid JSON body"})}
 const action=String(body.action||""),assignmentId=String(body.assignment_id||"");
 if(!["start","stop"].includes(action)||!UUID.test(assignmentId))return reply(400,{error:"A valid tracking action and driver assignment are required"});
 if(action==="start"&&(!gpsLaunchApproved||!CONSENT_NOTICE_APPROVED))return reply(503,{error:"Driver GPS sharing is paused until KRIM approves the exact consent notice, retention schedule, deletion/legal-hold controls and launch review."});
 const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const userId=authData.user.id;
 const {data:driver,error:driverError}=await admin.from("krim_driver_assignments")
  .select("id,user_id,organization_id,shipment_id,shipment_leg_id,partner_assignment_id,status")
  .eq("id",assignmentId).eq("user_id",userId).maybeSingle();
 if(driverError)return reply(500,{error:"Could not verify driver assignment"});
 if(!driver||!driver.shipment_id||!driver.partner_assignment_id)return reply(403,{error:"No linked shipment assignment is available"});
 if(action==="stop"){
  const {data:active,error:activeError}=await admin.from("krim_driver_tracking_sessions").select("id").eq("driver_assignment_id",assignmentId).eq("user_id",userId).eq("status","active").maybeSingle();
  if(activeError)return reply(500,{error:"Could not locate active tracking session"});
  if(!active)return reply(200,{success:true,stopped:false,message:"No active tracking session exists"});
  const {error:updateError}=await admin.from("krim_driver_tracking_sessions").update({status:"stopped",stopped_at:new Date().toISOString(),stop_reason:"driver_stopped"}).eq("id",active.id).eq("user_id",userId).eq("status","active");
  if(updateError)return reply(500,{error:"Tracking session could not be stopped"});
  return reply(200,{success:true,stopped:true,session_id:active.id});
 }
 const {data:membership,error:membershipError}=await admin.from("krim_organization_members")
  .select("organization_id").eq("organization_id",driver.organization_id).eq("user_id",userId).eq("role","driver").eq("status","active").maybeSingle();
 if(membershipError)return reply(500,{error:"Could not verify active driver membership"});
 if(!membership)return reply(403,{error:"Active driver membership is required"});
 const {data:organization,error:orgError}=await admin.from("krim_organizations").select("id,status").eq("id",driver.organization_id).maybeSingle();
 if(orgError)return reply(500,{error:"Could not verify operating organization"});
 if(!organization||String(organization.status).toLowerCase()!=="active")return reply(403,{error:"Driver organization is not active"});
 const {data:profile,error:profileError}=await admin.from("krim_driver_profiles").select("id,verification_status,licence_number").eq("user_id",userId).eq("organization_id",driver.organization_id).maybeSingle();
 if(profileError)return reply(500,{error:"Could not verify driver identity"});
 if(!profile||!["verified","approved"].includes(String(profile.verification_status).toLowerCase())||!String(profile.licence_number||"").trim())return reply(403,{error:"Verified driver identity and licence are required before location sharing"});
 if(String(driver.status).toLowerCase()!=="in_transit")return reply(409,{error:"Location sharing is available only after the trip is marked in transit"});
 const {data:partner,error:partnerError}=await admin.from("krim_shipment_partner_assignments")
  .select("id,shipment_id,shipment_leg_id,partner_organization_id,status")
  .eq("id",driver.partner_assignment_id).eq("shipment_id",driver.shipment_id).eq("partner_organization_id",driver.organization_id).maybeSingle();
 if(partnerError)return reply(500,{error:"Could not verify partner shipment assignment"});
 if(!partner||!["accepted","active","in_progress","assigned"].includes(String(partner.status).toLowerCase()))return reply(403,{error:"The linked partner shipment assignment is not active"});
 if(!driver.shipment_leg_id||String(driver.shipment_leg_id)!==String(partner.shipment_leg_id))return reply(403,{error:"Driver and partner assignment shipment legs do not match"});
 const platform=String(body.platform||"");
 if(!["android","ios"].includes(platform))return reply(400,{error:"GPS sharing is available only through the KRIM Driver native app"});
 const consentVersion=String(body.consent_version||"");
 if(consentVersion!==CONSENT_NOTICE_VERSION)return reply(400,{error:"Please review and accept the current location-sharing notice"});
 const consentHash=await sha256Hex(CONSENT_NOTICE_TEXT);
 const {data:existing,error:existingError}=await admin.from("krim_driver_tracking_sessions").select("id,status,started_at,platform,consent_version,consent_notice_sha256")
  .eq("driver_assignment_id",assignmentId).eq("user_id",userId).eq("status","active").maybeSingle();
 if(existingError)return reply(500,{error:"Could not check existing tracking session"});
 if(existing){
  if(existing.platform!==platform||existing.consent_version!==CONSENT_NOTICE_VERSION||existing.consent_notice_sha256!==consentHash)return reply(409,{error:"An active session uses a different platform or consent notice. Stop it and review the current notice before starting again"});
  return reply(200,{success:true,started:true,session_id:existing.id,started_at:existing.started_at,already_active:true,consent_notice_version:CONSENT_NOTICE_VERSION,consent_notice_sha256:consentHash});
 }
 const {data:created,error:createError}=await admin.from("krim_driver_tracking_sessions").insert({
  driver_assignment_id:assignmentId,partner_assignment_id:driver.partner_assignment_id,shipment_id:driver.shipment_id,
  shipment_leg_id:driver.shipment_leg_id||partner.shipment_leg_id||null,organization_id:driver.organization_id,user_id:userId,
  consent_version:consentVersion,consent_notice_text:CONSENT_NOTICE_TEXT,consent_notice_sha256:consentHash,consent_language:CONSENT_NOTICE_LANGUAGE,platform,status:"active"
 }).select("id,started_at").single();
 if(createError){
  const {data:retry}=await admin.from("krim_driver_tracking_sessions").select("id,started_at,platform,consent_version,consent_notice_sha256").eq("driver_assignment_id",assignmentId).eq("user_id",userId).eq("status","active").maybeSingle();
  if(retry){if(retry.platform===platform&&retry.consent_version===CONSENT_NOTICE_VERSION&&retry.consent_notice_sha256===consentHash)return reply(200,{success:true,started:true,session_id:retry.id,started_at:retry.started_at,already_active:true,consent_notice_version:CONSENT_NOTICE_VERSION,consent_notice_sha256:consentHash});return reply(409,{error:"A different active consent session already exists; stop it and review the current notice"});}
  return reply(500,{error:"Tracking consent session could not be recorded"});
 }
 return reply(201,{success:true,started:true,session_id:created.id,started_at:created.started_at,already_active:false});
});