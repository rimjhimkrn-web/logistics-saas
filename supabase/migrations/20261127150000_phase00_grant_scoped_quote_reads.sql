-- Phase 00: least-privilege quote reads for authenticated customer/partner
-- frontends. Existing organization-scoped RLS SELECT policies remain in force.
-- No quote table write privileges are granted.
GRANT SELECT (
  id,
  opportunity_id,
  shipment_id,
  partner_organization_id,
  quote_number,
  amount,
  currency_code,
  status,
  submitted_at,
  valid_until,
  notes
) ON TABLE public.krim_partner_quotes TO authenticated;

GRANT SELECT (
  id,
  shipment_id,
  customer_organization_id,
  amount,
  currency_code,
  status,
  valid_until,
  partner_quote_id,
  created_at,
  pricing_snapshot
) ON TABLE public.krim_quotes TO authenticated;
