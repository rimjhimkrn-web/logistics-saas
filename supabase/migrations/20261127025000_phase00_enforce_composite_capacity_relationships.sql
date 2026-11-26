-- Phase 00: database-enforced shipment/leg/partner/capacity relationships.
-- Parent composite keys are unique even though their leading IDs are already unique.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_capacity_binding_identity
 ON public.krim_capacity_leg_bindings(id,shipment_id,shipment_leg_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_capacity_reservation_identity
 ON public.krim_capacity_reservations(id,shipment_id,shipment_leg_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_capacity_availability_org_identity
 ON public.krim_partner_capacity_availability(id,organization_id);

DO $migration$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_capacity_binding_leg_shipment' AND conrelid='public.krim_capacity_leg_bindings'::regclass) THEN
  ALTER TABLE public.krim_capacity_leg_bindings
   ADD CONSTRAINT fk_krim_capacity_binding_leg_shipment
   FOREIGN KEY (shipment_leg_id,shipment_id)
   REFERENCES public.krim_shipment_legs(id,shipment_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_capacity_reservation_leg_shipment' AND conrelid='public.krim_capacity_reservations'::regclass) THEN
  ALTER TABLE public.krim_capacity_reservations
   ADD CONSTRAINT fk_krim_capacity_reservation_leg_shipment
   FOREIGN KEY (shipment_leg_id,shipment_id)
   REFERENCES public.krim_shipment_legs(id,shipment_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_assignment_leg_shipment' AND conrelid='public.krim_shipment_partner_assignments'::regclass) THEN
  ALTER TABLE public.krim_shipment_partner_assignments
   ADD CONSTRAINT fk_krim_assignment_leg_shipment
   FOREIGN KEY (shipment_leg_id,shipment_id)
   REFERENCES public.krim_shipment_legs(id,shipment_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_activation_leg_shipment' AND conrelid='public.krim_partner_assignment_activations'::regclass) THEN
  ALTER TABLE public.krim_partner_assignment_activations
   ADD CONSTRAINT fk_krim_activation_leg_shipment
   FOREIGN KEY (shipment_leg_id,shipment_id)
   REFERENCES public.krim_shipment_legs(id,shipment_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_reservation_capacity_org' AND conrelid='public.krim_capacity_reservations'::regclass) THEN
  ALTER TABLE public.krim_capacity_reservations
   ADD CONSTRAINT fk_krim_reservation_capacity_org
   FOREIGN KEY (capacity_availability_id,organization_id)
   REFERENCES public.krim_partner_capacity_availability(id,organization_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_capacity_binding_reservation_identity' AND conrelid='public.krim_capacity_leg_bindings'::regclass) THEN
  ALTER TABLE public.krim_capacity_leg_bindings
   ADD CONSTRAINT fk_krim_capacity_binding_reservation_identity
   FOREIGN KEY (reservation_id,shipment_id,shipment_leg_id)
   REFERENCES public.krim_capacity_reservations(id,shipment_id,shipment_leg_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_assignment_capacity_identity' AND conrelid='public.krim_shipment_partner_assignments'::regclass) THEN
  ALTER TABLE public.krim_shipment_partner_assignments
   ADD CONSTRAINT fk_krim_assignment_capacity_identity
   FOREIGN KEY (capacity_binding_id,shipment_id,shipment_leg_id)
   REFERENCES public.krim_capacity_leg_bindings(id,shipment_id,shipment_leg_id) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_krim_activation_capacity_identity' AND conrelid='public.krim_partner_assignment_activations'::regclass) THEN
  ALTER TABLE public.krim_partner_assignment_activations
   ADD CONSTRAINT fk_krim_activation_capacity_identity
   FOREIGN KEY (capacity_binding_id,shipment_id,shipment_leg_id)
   REFERENCES public.krim_capacity_leg_bindings(id,shipment_id,shipment_leg_id) NOT VALID;
 END IF;
END
$migration$;

ALTER TABLE public.krim_capacity_leg_bindings VALIDATE CONSTRAINT fk_krim_capacity_binding_leg_shipment;
ALTER TABLE public.krim_capacity_reservations VALIDATE CONSTRAINT fk_krim_capacity_reservation_leg_shipment;
ALTER TABLE public.krim_shipment_partner_assignments VALIDATE CONSTRAINT fk_krim_assignment_leg_shipment;
ALTER TABLE public.krim_partner_assignment_activations VALIDATE CONSTRAINT fk_krim_activation_leg_shipment;
ALTER TABLE public.krim_capacity_reservations VALIDATE CONSTRAINT fk_krim_reservation_capacity_org;
ALTER TABLE public.krim_capacity_leg_bindings VALIDATE CONSTRAINT fk_krim_capacity_binding_reservation_identity;
ALTER TABLE public.krim_shipment_partner_assignments VALIDATE CONSTRAINT fk_krim_assignment_capacity_identity;
ALTER TABLE public.krim_partner_assignment_activations VALIDATE CONSTRAINT fk_krim_activation_capacity_identity;
