-- Phase 00: restore authenticated read access to route-plan history.
-- All five tables have RLS enabled and customer-organization-scoped SELECT
-- policies. No direct INSERT, UPDATE, or DELETE access is granted.

GRANT SELECT ON TABLE
  public.krim_shipment_leg_plans,
  public.krim_shipment_leg_plan_items,
  public.krim_shipment_leg_plan_events,
  public.krim_shipment_leg_activations,
  public.krim_shipment_leg_activation_events
TO authenticated;

REVOKE ALL ON TABLE
  public.krim_shipment_leg_plans,
  public.krim_shipment_leg_plan_items,
  public.krim_shipment_leg_plan_events,
  public.krim_shipment_leg_activations,
  public.krim_shipment_leg_activation_events
FROM anon;
