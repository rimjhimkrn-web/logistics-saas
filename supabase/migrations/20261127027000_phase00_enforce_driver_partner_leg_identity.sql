-- Enforce exact driver-to-partner assignment ownership and leg identity.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_partner_assignment_driver_link
ON public.krim_shipment_partner_assignments
(id, shipment_id, shipment_leg_id, partner_organization_id);

ALTER TABLE public.krim_driver_assignments
  ADD CONSTRAINT chk_krim_driver_assignment_partner_link_complete
  CHECK (
    partner_assignment_id IS NULL
    OR (shipment_id IS NOT NULL AND shipment_leg_id IS NOT NULL)
  ) NOT VALID;

ALTER TABLE public.krim_driver_assignments
  VALIDATE CONSTRAINT chk_krim_driver_assignment_partner_link_complete;

ALTER TABLE public.krim_driver_assignments
  ADD CONSTRAINT fk_krim_driver_assignment_exact_partner_leg
  FOREIGN KEY (partner_assignment_id, shipment_id, shipment_leg_id, organization_id)
  REFERENCES public.krim_shipment_partner_assignments
    (id, shipment_id, shipment_leg_id, partner_organization_id)
  NOT VALID;

ALTER TABLE public.krim_driver_assignments
  VALIDATE CONSTRAINT fk_krim_driver_assignment_exact_partner_leg;
