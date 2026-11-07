import type { SupabaseClient } from "@supabase/supabase-js";

export type PartnerOrganization = {
  id:number; organization_type:string; legal_name:string; display_name:string|null;
  status:string; partner_lifecycle_status:string|null; partner_verification_status:string|null;
  partner_compliance_status:string|null; partner_onboarding_status:string|null;
  partner_account_mode:string|null; role:string;
};
export type PartnerCapability = {
  id:number; transport_mode_id:number; service_type:string; coverage_region:string|null;
  max_weight_kg:number|null; refrigerated:boolean; hazardous_goods_capable:boolean;
  active:boolean; verification_status:string|null; effective_from:string|null; effective_until:string|null;
};
export type PartnerOpportunity = {
  id:number; shipment_id:number; opportunity_number:string; status:string;
  requested_at:string; response_deadline:string|null; service_lane:string|null;
  partner_name:string|null; shipment?:PartnerShipment|null;
};
export type PartnerShipment = {
  id:number; shipment_number:string; status:string; origin_place_label:string|null;
  destination_place_label:string|null; goods_description:string|null; total_weight_kg:number|null;
  requested_transport_mode:string|null; requested_route_type:string|null; created_at:string;
};
export type PartnerQuote = {
  id:number; opportunity_id:number; shipment_id:number; quote_number:string;
  amount:number; currency_code:string; valid_until:string; status:string;
  submitted_at:string; notes:string|null;
};
export type PartnerAssignment = {
  id:number; shipment_id:number; partner_quote_id:number|null; assignment_number:string;
  status:string; offered_at:string; response_deadline:string|null; accepted_at:string|null;
  rejected_at:string|null;
};

export async function loadPartnerOrganizations(client:SupabaseClient,userId:string):Promise<PartnerOrganization[]>{
 const {data:members,error:memberError}=await client.from("krim_organization_members")
  .select("organization_id,role,status").eq("user_id",userId).eq("status","active");
 if(memberError) throw memberError;
 const eligible=(members??[]).filter(m=>true);
 if(!eligible.length)return [];
 const ids=[...new Set(eligible.map(m=>Number(m.organization_id)))];
 const {data:orgs,error}=await client.from("krim_organizations")
  .select("id,organization_type,legal_name,display_name,status,partner_lifecycle_status,partner_verification_status,partner_compliance_status,partner_onboarding_status,partner_account_mode")
  .in("id",ids).in("organization_type",["partner","carrier","forwarder"]);
 if(error)throw error;
 const roles=new Map<number,string>(); for(const m of eligible)roles.set(Number(m.organization_id),String(m.role));
 return (orgs??[]).map(o=>({...o,id:Number(o.id),role:roles.get(Number(o.id))??"member"}));
}
export async function loadPartnerCapabilities(client:SupabaseClient,organizationId:number):Promise<PartnerCapability[]>{
 const {data,error}=await client.from("krim_partner_capabilities")
 .select("id,transport_mode_id,service_type,coverage_region,max_weight_kg,refrigerated,hazardous_goods_capable,active,verification_status,effective_from,effective_until")
 .eq("organization_id",organizationId).order("created_at",{ascending:false}).limit(100);
 if(error)throw error;return (data??[]) as PartnerCapability[];
}
export async function loadPartnerOpportunities(client:SupabaseClient):Promise<PartnerOpportunity[]>{
 const {data,error}=await client.from("krim_partner_opportunities")
 .select("id,shipment_id,opportunity_number,status,requested_at,response_deadline,service_lane,partner_name")
 .eq("status","open").order("requested_at",{ascending:false}).limit(100);
 if(error)throw error;
 const rows=(data??[]) as PartnerOpportunity[];
 const shipmentIds=[...new Set(rows.map(x=>Number(x.shipment_id)))];
 if(!shipmentIds.length)return rows;
 const {data:shipments,error:shipmentError}=await client.from("krim_shipments")
 .select("id,shipment_number,status,origin_place_label,destination_place_label,goods_description,total_weight_kg,requested_transport_mode,requested_route_type,created_at")
 .in("id",shipmentIds);
 if(shipmentError)throw shipmentError;
 const byId=new Map<number,PartnerShipment>((shipments??[]).map(x=>[Number(x.id),x as PartnerShipment]));
 return rows.map(x=>({...x,shipment:byId.get(Number(x.shipment_id))??null}));
}
export async function loadPartnerQuotes(client:SupabaseClient,organizationId:number):Promise<PartnerQuote[]>{
 const {data,error}=await client.from("krim_partner_quotes")
 .select("id,opportunity_id,shipment_id,quote_number,amount,currency_code,valid_until,status,submitted_at,notes")
 .eq("partner_organization_id",organizationId).order("created_at",{ascending:false}).limit(100);
 if(error)throw error;return (data??[]) as PartnerQuote[];
}
export async function loadPartnerAssignments(client:SupabaseClient,organizationId:number):Promise<PartnerAssignment[]>{
 const {data,error}=await client.from("krim_shipment_partner_assignments")
 .select("id,shipment_id,partner_quote_id,assignment_number,status,offered_at,response_deadline,accepted_at,rejected_at")
 .eq("partner_organization_id",organizationId).order("created_at",{ascending:false}).limit(100);
 if(error)throw error;return (data??[]) as PartnerAssignment[];
}
