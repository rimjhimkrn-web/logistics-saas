import { createClient } from "npm:@supabase/supabase-js@2";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Cache-Control":"no-store","Content-Type":"application/json"};
const CONSENT_NOTICE_VERSION = "2026-11-15-v1";
const CONSENT_NOTICE_LANGUAGE = "en-IN";
const CONSENT_NOTICE_APPROVED = false;
const CONSENT_NOTICE_TEXT = "KRIM Driver location sharing (draft notice — GPS remains disabled): If and when KRIM enables this feature after publishing an approved GPS retention period, deletion process and legal-hold terms, this app will share this device location only for the shipment assignment selected by you and marked In Transit. Location may be visible to KRIM operations personnel and the customer/shipper authorized for that shipment. You may decline or stop sharing at any time. Android background sharing requires location permission and an ongoing location notification; if background permission is not granted, only foreground sharing can operate. Location can be delayed or interrupted by device, battery, GPS or network conditions. Do not use the phone while driving. KRIM location tracking is not emergency monitoring or safety-critical navigation. This draft notice is not approved for commercial use. GPS collection remains disabled until the approved notice and retention terms are published and the legal launch gate is opened.";
async function sha256Hex(value:string):Promise<string>{
 const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
 return Array.from(new Uint8Array(digest)).map(byte=>byte.toString(16).padStart(2,"0")).join("");
}
function reply(status:number,body:Record<string,unknown>){return new Response(JSON.stringify(body),{status,headers:cors});}
const gpsLaunchApproved = Deno.env.get("KRIM_GPS_TRACKING_ENABLED") === "true"
 && Deno.env.get("KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION") === CONSENT_NOTICE_VERSION;

Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 if(!gpsLaunchApproved||!CONSENT_NOTICE_APPROVED)return reply(503,{error:"Driver GPS uploads are paused until the exact consent notice, retention schedule, deletion/legal-hold controls and launch review are approved."});
 const authorization=req.headers.get("Authorization")||"";
 const token=authorization.toLowerCase().startsWith("bearer ") ? authorization.slice(7).trim() : authorization.trim();
 if(!token)return reply(401,{error:"Authentication required"});
 const url=Deno.env.get("SUPABASE_URL")!;
 const publishableKey=Deno.env.get("SUPABASE_ANON_KEY")||Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
 const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 if(!url||!publishableKey||!serviceKey)return reply(500,{error:"Tracking service is not configured"});
 const authClient=createClient(url,publishableKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:authData,error:authError}=await authClient.auth.getUser(token);
 if(authError||!authData.user)return reply(401,{error:"Session is invalid or expired"});
 let body:Record<string,unknown>;try{body=await req.json()}catch{return reply(400,{error:"Invalid JSON body"})}
 const assignmentId=String(body.assignment_id||"");
 const trackingSessionId=String(body.tracking_session_id||"");
 const lat=Number(body.latitude),lon=Number(body.longitude),accuracy=Number(body.accuracy_m),deviceTimestamp=Number(body.device_timestamp);
 const heading=body.heading_degrees==null?null:Number(body.heading_degrees),speed=body.speed_mps==null?null:Number(body.speed_mps);
 const collectionMethod=String(body.collection_method||"");
 const clientPlatform=String(body.client_platform||"");
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(assignmentId)||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(trackingSessionId))return reply(400,{error:"A valid driver assignment and active tracking session are required"});
 if(!Number.isFinite(lat)||lat< -90||lat>90||!Number.isFinite(lon)||lon< -180||lon>180)return reply(400,{error:"GPS coordinates are invalid"});
 if(!Number.isFinite(accuracy)||accuracy<=0||accuracy>250)return reply(422,{error:"GPS accuracy must be 250 metres or better"});
 const now=Date.now();if(!Number.isFinite(deviceTimestamp)||Math.abs(now-deviceTimestamp)>300000)return reply(422,{error:"Device GPS timestamp is stale or invalid"});
 if(!["expo_location_background","expo_location_foreground"].includes(collectionMethod))return reply(400,{error:"Only native KRIM Driver location collection methods are accepted"});
 if(!["android","ios"].includes(clientPlatform))return reply(400,{error:"Only the KRIM Driver native app is authorized for GPS updates"});
 if(heading!==null&&(!Number.isFinite(heading)||heading<0||heading>=360))return reply(400,{error:"Heading is invalid"});
 if(speed!==null&&(!Number.isFinite(speed)||speed<0||speed>100))return reply(400,{error:"Speed is invalid"});
 const expectedConsentHash=await sha256Hex(CONSENT_NOTICE_TEXT);
 const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:driver,error:driverError}=await admin.from("krim_driver_assignments").select("id,user_id,organization_id,shipment_id,shipment_leg_id,partner_assignment_id,status").eq("id",assignmentId).eq("user_id",authData.user.id).maybeSingle();
 if(driverError)return reply(500,{error:"Could not verify driver assignment"});
 if(!driver||!driver.partner_assignment_id||!driver.shipment_id)return reply(403,{error:"No matching active driver assignment is available"});
 if(String(driver.status||"").toLowerCase()!=="in_transit"){
  await admin.from("krim_driver_tracking_sessions").update({status:"stopped",stopped_at:new Date().toISOString(),stop_reason:"assignment_not_in_transit"})
   .eq("id",trackingSessionId).eq("driver_assignment_id",driver.id).eq("user_id",authData.user.id).eq("status","active");
  return reply(409,{error:"GPS updates are accepted only for a trip currently marked in transit"});
 }
 const {data:profile,error:profileError}=await admin.from("krim_driver_profiles").select("id,verification_status,licence_number").eq("user_id",authData.user.id).eq("organization_id",driver.organization_id).maybeSingle();
 if(profileError)return reply(500,{error:"Could not verify driver identity"});
 if(!profile||!["verified","approved"].includes(String(profile.verification_status).toLowerCase())||!String(profile.licence_number||"").trim())return reply(403,{error:"Verified driver identity and licence are required for GPS updates"});
 const {data:trackingSession,error:sessionError}=await admin.from("krim_driver_tracking_sessions").select("id,driver_assignment_id,partner_assignment_id,shipment_id,organization_id,user_id,status,platform,consent_version,consent_notice_text,consent_notice_sha256,consent_language").eq("id",trackingSessionId).eq("driver_assignment_id",driver.id).eq("partner_assignment_id",driver.partner_assignment_id).eq("shipment_id",driver.shipment_id).eq("organization_id",driver.organization_id).eq("user_id",authData.user.id).eq("status","active").maybeSingle();
 if(sessionError)return reply(500,{error:"Could not verify tracking consent session"});
 if(!trackingSession)return reply(403,{error:"An active, consented tracking session is required before location updates are accepted"});
 if(trackingSession.platform!==clientPlatform)return reply(403,{error:"Tracking client does not match the consented session platform"});
 if(trackingSession.consent_version!==CONSENT_NOTICE_VERSION||trackingSession.consent_notice_text!==CONSENT_NOTICE_TEXT||trackingSession.consent_notice_sha256!==expectedConsentHash||trackingSession.consent_language!==CONSENT_NOTICE_LANGUAGE)return reply(403,{error:"The exact archived consent notice does not match the active tracking session"});
 const {data:membership,error:membershipError}=await admin.from("krim_organization_members").select("organization_id,role,status").eq("organization_id",driver.organization_id).eq("user_id",authData.user.id).eq("role","driver").eq("status","active").maybeSingle();
 if(membershipError)return reply(500,{error:"Could not verify driver membership"});
 if(!membership)return reply(403,{error:"Active driver organization membership is required"});
 const {data:organization,error:organizationError}=await admin.from("krim_organizations").select("id,status").eq("id",driver.organization_id).maybeSingle();
 if(organizationError)return reply(500,{error:"Could not verify driver organization"});
 if(!organization||String(organization.status).toLowerCase()!=="active")return reply(403,{error:"Driver organization is not active"});
 const {data:partnerAssignment,error:partnerError}=await admin.from("krim_shipment_partner_assignments").select("id,shipment_id,shipment_leg_id,partner_organization_id,status").eq("id",driver.partner_assignment_id).eq("shipment_id",driver.shipment_id).eq("partner_organization_id",driver.organization_id).maybeSingle();
 if(partnerError)return reply(500,{error:"Could not verify shipment assignment"});
 if(!partnerAssignment||!["accepted","active","in_progress","assigned"].includes(String(partnerAssignment.status).toLowerCase()))return reply(403,{error:"The linked shipment assignment is not authorized for tracking"});
 if(!driver.shipment_leg_id||String(driver.shipment_leg_id)!==String(partnerAssignment.shipment_leg_id))return reply(403,{error:"Driver and partner assignment shipment legs do not match"});
 const {data:latest,error:latestError}=await admin.from("krim_tracking_events").select("event_time,latitude,longitude").eq("assignment_id",driver.partner_assignment_id).eq("source_type","gps").order("event_time",{ascending:false}).limit(1).maybeSingle();
 if(latestError)return reply(500,{error:"Could not check tracking frequency"});
 if(latest){const elapsed=now-new Date(latest.event_time).getTime();const rad=(v:number)=>v*Math.PI/180;const dLat=rad(lat-Number(latest.latitude??lat)),dLon=rad(lon-Number(latest.longitude??lon));const a=Math.sin(dLat/2)**2+Math.cos(rad(lat))*Math.cos(rad(Number(latest.latitude??lat)))*Math.sin(dLon/2)**2;const distance=6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(1-a));if(elapsed<15000)return reply(202,{accepted:true,stored:false,reason:"rate_limited",next_update_after_ms:15000-elapsed});if(distance<15&&elapsed<60000)return reply(202,{accepted:true,stored:false,reason:"stationary_filter"});}
 const {data:inserted,error:insertError}=await admin.from("krim_tracking_events").insert({shipment_id:driver.shipment_id,shipment_leg_id:driver.shipment_leg_id||partnerAssignment.shipment_leg_id||null,event_type:"gps_position",event_time:new Date(now).toISOString(),source_type:"gps",source_reference:"driver:"+authData.user.id+":assignment:"+driver.id+":session:"+trackingSessionId,latitude:lat,longitude:lon,partner_organization_id:driver.organization_id,assignment_id:driver.partner_assignment_id,metadata:{tracking_session_id:trackingSessionId,consent_notice_sha256:expectedConsentHash,accuracy_m:accuracy,heading_degrees:heading,speed_mps:speed,device_timestamp:new Date(deviceTimestamp).toISOString(),collection_method:collectionMethod,client_platform:clientPlatform,device_reported_mocked:Boolean(body.device_reported_mocked)}}).select("id,event_time,latitude,longitude").single();
 if(insertError)return reply(500,{error:"GPS update could not be stored"});
 return reply(201,{accepted:true,stored:true,event:inserted});
});