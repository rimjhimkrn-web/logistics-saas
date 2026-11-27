-- Phase 00: grant only the assignment columns required by customer/partner
-- operational frontends. Row access remains governed by the existing RLS
-- organization-scope policy; no INSERT/UPDATE/DELETE privileges are added.
GRANT SELECT (
  id,
  shipment_id,
  shipment_leg_id,
  capacity_binding_id,
  partner_organization_id,
  partner_quote_id,
  assignment_number,
  status,
  offered_at,
  response_deadline,
  created_at
) ON TABLE public.krim_shipment_partner_assignments TO authenticated;
