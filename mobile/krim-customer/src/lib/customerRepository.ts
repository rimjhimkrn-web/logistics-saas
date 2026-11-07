import type { SupabaseClient } from "@supabase/supabase-js";

export type CustomerOrganization = {
  id: number;
  organization_type: string;
  legal_name: string;
  display_name: string | null;
  default_currency_code: string | null;
  timezone: string | null;
  status: string;
  role: string;
};

export type CustomerShipment = {
  id: number;
  shipment_number: string;
  customer_organization_id: number;
  status: string;
  origin_place_label: string | null;
  destination_place_label: string | null;
  goods_description: string | null;
  total_weight_kg: number | null;
  requested_transport_mode: string | null;
  estimated_delivery_at: string | null;
  actual_delivery_at: string | null;
  created_at: string;
};

export type CustomerQuote = {
  id: number;
  shipment_id: number;
  amount: number;
  currency_code: string;
  valid_until: string;
  status: string;
  created_at: string;
};

const ORGANIZATION_FIELDS =
  "id,organization_type,legal_name,display_name,default_currency_code,timezone,status";
const SHIPMENT_FIELDS =
  "id,shipment_number,customer_organization_id,status,origin_place_label,destination_place_label,goods_description,total_weight_kg,requested_transport_mode,estimated_delivery_at,actual_delivery_at,created_at";
const QUOTE_FIELDS =
  "id,shipment_id,amount,currency_code,valid_until,status,created_at";

export async function loadCustomerOrganizations(
  client: SupabaseClient,
  userId: string,
): Promise<CustomerOrganization[]> {
  const memberships = await client
    .from("krim_organization_members")
    .select("organization_id,role,status")
    .eq("user_id", userId)
    .eq("status", "active");

  if (memberships.error) throw memberships.error;
  const active = memberships.data ?? [];
  if (!active.length) return [];

  const ids = [...new Set(active.map((m) => Number(m.organization_id)))];
  const organizations = await client
    .from("krim_organizations")
    .select(ORGANIZATION_FIELDS)
    .in("id", ids)
    .eq("status", "active");

  if (organizations.error) throw organizations.error;
  const roleById = new Map<number, string>();
  for (const membership of active) {
    roleById.set(Number(membership.organization_id), String(membership.role));
  }

  return (organizations.data ?? []).map((org) => ({
    ...org,
    id: Number(org.id),
    role: roleById.get(Number(org.id)) ?? "member",
  }));
}

export async function loadCustomerShipments(
  client: SupabaseClient,
  organizationId: number,
): Promise<CustomerShipment[]> {
  const { data, error } = await client
    .from("krim_shipments")
    .select(SHIPMENT_FIELDS)
    .eq("customer_organization_id", organizationId)
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) throw error;
  return (data ?? []) as CustomerShipment[];
}

export async function loadCustomerQuotes(
  client: SupabaseClient,
  organizationId: number,
): Promise<CustomerQuote[]> {
  const { data, error } = await client
    .from("krim_quotes")
    .select(QUOTE_FIELDS)
    .eq("customer_organization_id", organizationId)
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) throw error;
  return (data ?? []) as CustomerQuote[];
}

export async function loadShipmentTracking(
  client: SupabaseClient,
  shipmentNumber: string,
): Promise<Record<string, unknown>> {
  const { data, error } = await client.rpc("krim_get_shipment_tracking", {
    p_shipment_number: shipmentNumber,
  });

  if (error) throw error;
  if (!data || typeof data !== "object") {
    throw new Error("Tracking information is not available.");
  }
  return data as Record<string, unknown>;
}
