-- Preserve historical capacity bindings while allowing a fresh active binding after expiry/release.
-- Only one live binding may exist per shipment leg at a time.
DROP INDEX IF EXISTS public.uq_krim_capacity_leg_binding_leg;
CREATE UNIQUE INDEX uq_krim_capacity_leg_binding_leg_active
  ON public.krim_capacity_leg_bindings (shipment_leg_id)
  WHERE status IN ('pending','held','confirmed');
COMMENT ON INDEX public.uq_krim_capacity_leg_binding_leg_active IS
  'Allows historical released/expired/cancelled/failed bindings while preventing more than one pending, held or confirmed binding per shipment leg.';
