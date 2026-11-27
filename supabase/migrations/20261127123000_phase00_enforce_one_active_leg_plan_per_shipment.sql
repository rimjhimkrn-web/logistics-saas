-- Phase 00: prevent ambiguous active route-plan selection per shipment.
-- Staging-only migration; a partial unique index allows any number of historical
-- draft/ready/superseded/cancelled plans while permitting at most one active plan.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_shipment_leg_plans_one_active_per_shipment
  ON public.krim_shipment_leg_plans (shipment_id)
  WHERE status = 'active';
