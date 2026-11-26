-- Phase 00: an activation must describe the exact assignment and its selected binding.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_assignment_identity_binding
 ON public.krim_shipment_partner_assignments(id,capacity_binding_id,shipment_id,shipment_leg_id);

DO $migration$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_activation_exact_assignment' AND conrelid='public.krim_partner_assignment_activations'::regclass) THEN
  ALTER TABLE public.krim_partner_assignment_activations
   ADD CONSTRAINT fk_krim_activation_exact_assignment
   FOREIGN KEY (assignment_id,capacity_binding_id,shipment_id,shipment_leg_id)
   REFERENCES public.krim_shipment_partner_assignments(id,capacity_binding_id,shipment_id,shipment_leg_id)
   NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_krim_activated_requires_capacity_binding' AND conrelid='public.krim_partner_assignment_activations'::regclass) THEN
  ALTER TABLE public.krim_partner_assignment_activations
   ADD CONSTRAINT chk_krim_activated_requires_capacity_binding
   CHECK (status <> 'activated' OR capacity_binding_id IS NOT NULL) NOT VALID;
 END IF;
END
$migration$;

ALTER TABLE public.krim_partner_assignment_activations VALIDATE CONSTRAINT fk_krim_activation_exact_assignment;
ALTER TABLE public.krim_partner_assignment_activations VALIDATE CONSTRAINT chk_krim_activated_requires_capacity_binding;
