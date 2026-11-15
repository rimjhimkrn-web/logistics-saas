import { createClient } from "npm:@supabase/supabase-js@2";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Cache-Control":"no-store","Content-Type":"application/json"};
function reply(status:number,body:Record<string,unknown>){return new Response(JSON.stringify(body),{status,headers:cors});}
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 const authorization=req.headers.get("Authorization")||"";
 const token=authorization.replace(/^Bearer\\s+/i,"").trim();
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
 const lat=Number(body.latitude),lon=Number(body.longitude),accuracy=Number(body.accuracy_m),deviceTimestamp=Number(body.device_timestamp);
 const heading=body.heading_degrees==null?null:Number(body.heading_degrees),speed=body.speed_mps==null?null:Number(body.speed_mps);
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(assignmentId))return reply(400,{error:"A valid driver assignment is required"});
 if(!Number.isFinite(lat)||lat< -90||lat>90||!Number.isFinite(lon)||lon< -180||lon>180)return reply(400,{error:"GPS coordinates are invalid"});
 if(!Number.isFinite(accuracy)||accuracy<=0||accuracy>250)return reply(422,{error:"GPS accuracy must be 250 metres or better"});
 const now=Date.now();if(!Number.isFinite(deviceTimestamp)||Math.abs(now-deviceTimestamp)>300000)return reply(422,{error:"Device GPS timestamp is stale or invalid"});
 if(heading!==null&&(!Number.isFinite(heading)||heading<0||heading>=360))return reply(400,{error:"Heading is invalid"});
 if(speed!==null&&(!Number.isFinite(speed)||speed<0||speed>100))return reply(400,{error:"Speed is invalid"});
 const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:driver,error:driverError}=await admin.from("krim_driver_assignments").select("id,user_id,organization_id,shipment_id,shipment_leg_id,partner_assignment_id,status").eq("id",assignmentId).eq("user_id",authData.user.id).maybeSingle();
 if(driverError)return reply(500,{error:"Could not verify driver assignment"});
 if(!driver||!driver.partner_assignment_id||!driver.shipment_id)return reply(403,{error:"No matching active driver assignment is available"});
 if(["cancelled","rejected","completed","delivered","closed"].includes(String(driver.status||"").toLowerCase()))return reply(409,{error:"This driver assignment is no longer active"});
 const {data:membership,error:membershipError}=await admin.from("krim_organization_members").select("organization_id,role,status").eq("organization_id",driver.organization_id).eq("user_id",authData.user.id).eq("role","driver").eq("status","active").maybeSingle();
 if(membershipError)return reply(500,{error:"Could not verify driver membership"});
 if(!membership)return reply(403,{error:"Active driver organization membership is required"});
 const {data:organization,error:organizationError}=await admin.from("krim_organizations").select("id,status").eq("id",driver.organization_id).maybeSingle();
 if(organizationError)return reply(500,{error:"Could not verify driver organization"});
 if(!organization||String(organization.status).toLowerCase()!=="active")return reply(403,{error:"Driver organization is not active"});
 const {data:partnerAssignment,error:partnerError}=await admin.from("krim_shipment_partner_assignments").select("id,shipment_id,shipment_leg_id,partner_organization_id,status").eq("id",driver.partner_assignment_id).eq("shipment_id",driver.shipment_id).eq("partner_organization_id",driver.organization_id).maybeSingle();
 if(partnerError)return reply(500,{error:"Could not verify shipment assignment"});
 if(!partnerAssignment||!["accepted","active","in_progress","assigned"].includes(String(partnerAssignment.status).toLowerCase()))return reply(403,{error:"The linked shipment assignment is not authorized for tracking"});
 const {data:latest,error:latestError}=await admin.from("krim_tracking_events").select("event_time,latitude,longitude").eq("assignment_id",driver.partner_assignment_id).eq("source_type","gps").order("event_time",{ascending:false}).limit(1).maybeSingle();
 if(latestError)return reply(500,{error:"Could not check tracking frequency"});
 if(latest){const elapsed=now-new Date(latest.event_time).getTime();const rad=(v:number)=>v*Math.PI/180;const dLat=rad(lat-Number(latest.latitude??lat)),dLon=rad(lon-Number(latest.longitude??lon));const a=Math.sin(dLat/2)**2+Math.cos(rad(lat))*Math.cos(rad(Number(latest.latitude??lat)))*Math.sin(dLon/2)**2;const distance=6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(1-a));if(elapsed<15000)return reply(202,{accepted:true,stored:false,reason:"rate_limited",next_update_after_ms:15000-elapsed});if(distance<15&&elapsed<60000)return reply(202,{accepted:true,stored:false,reason:"stationary_filter"});}
 const {data:inserted,error:insertError}=await admin.from("krim_tracking_events").insert({shipment_id:driver.shipment_id,shipment_leg_id:driver.shipment_leg_id||partnerAssignment.shipment_leg_id||null,event_type:"gps_position",event_time:new Date(now).toISOString(),source_type:"gps",source_reference:"driver:"+authData.user.id+":assignment:"+driver.id,latitude:lat,longitude:lon,partner_organization_id:driver.organization_id,assignment_id:driver.partner_assignment_id,metadata:{accuracy_m:accuracy,heading_degrees:heading,speed_mps:speed,device_timestamp:new Date(deviceTimestamp).toISOString(),collection_method:"browser_geolocation",foreground_only:true}}).select("id,event_time,latitude,longitude").single();
 if(insertError)return reply(500,{error:"GPS update could not be stored"});
 return reply(201,{accepted:true,stored:true,event:inserted});
});