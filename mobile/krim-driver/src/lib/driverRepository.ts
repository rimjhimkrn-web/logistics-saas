import type {SupabaseClient} from "@supabase/supabase-js";
export type DriverProfile={id:string;organization_id:number;full_name:string;country_code:string;phone:string;company_name:string;verification_status:string;onboarding_mode:string};
export type DriverAssignment={id:string;organization_id:number;shipment_id:number|null;shipment_dispatch_id:number|null;assignment_number:string;status:string;pickup_location:string;delivery_location:string;scheduled_pickup_at:string|null;scheduled_delivery_at:string|null;partner_assignment_id:number|null;shipment_leg_id:number|null;accepted_at:string|null;vehicle_id:string|null;created_at:string};
export type DriverTripEvent={id:string;assignment_id:string;event_type:string;notes:string;created_at:string};
export async function loadDriverProfiles(client:SupabaseClient,userId:string):Promise<DriverProfile[]>{
 const {data,error}=await client.from("krim_driver_profiles").select("id,organization_id,full_name,country_code,phone,company_name,verification_status,onboarding_mode").eq("user_id",userId).limit(20);
 if(error)throw error;return (data??[]) as DriverProfile[];
}
export async function loadDriverAssignments(client:SupabaseClient,userId:string):Promise<DriverAssignment[]>{
 const {data,error}=await client.from("krim_driver_assignments").select("id,organization_id,shipment_id,shipment_dispatch_id,assignment_number,status,pickup_location,delivery_location,scheduled_pickup_at,scheduled_delivery_at,partner_assignment_id,shipment_leg_id,accepted_at,vehicle_id,created_at").eq("user_id",userId).order("created_at",{ascending:false}).limit(100);
 if(error)throw error;return (data??[]) as DriverAssignment[];
}
export async function loadDriverTripEvents(client:SupabaseClient,assignmentIds:string[]):Promise<DriverTripEvent[]>{
 if(!assignmentIds.length)return [];
 const {data,error}=await client.from("krim_driver_trip_events").select("id,assignment_id,event_type,notes,created_at").in("assignment_id",assignmentIds).order("created_at",{ascending:false}).limit(200);
 if(error)throw error;return (data??[]) as DriverTripEvent[];
}

export type DriverDeliveryEvidence={id:string;assignment_id:string;user_id:string;recipient_name:string;notes:string|null;storage_path:string;original_file_name:string;content_type:string;file_size:number;created_at:string};
export async function loadDriverDeliveryEvidence(client:SupabaseClient,userId:string,assignmentIds:string[]):Promise<DriverDeliveryEvidence[]>{
 if(!assignmentIds.length)return [];
 const {data,error}=await client.from("krim_driver_delivery_evidence").select("id,assignment_id,user_id,recipient_name,notes,storage_path,original_file_name,content_type,file_size,created_at").eq("user_id",userId).in("assignment_id",assignmentIds).order("created_at",{ascending:false}).limit(100);
 if(error)throw error;return (data??[]) as DriverDeliveryEvidence[];
}
