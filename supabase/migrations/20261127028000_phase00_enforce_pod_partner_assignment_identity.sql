ALTER TABLE public.krim_pod_records
  ADD CONSTRAINT fk_krim_pod_exact_partner_assignment
  FOREIGN KEY (assignment_id, shipment_id, shipment_leg_id, partner_organization_id)
  REFERENCES public.krim_shipment_partner_assignments
    (id, shipment_id, shipment_leg_id, partner_organization_id)
  NOT VALID;

ALTER TABLE public.krim_pod_records
  VALIDATE CONSTRAINT fk_krim_pod_exact_partner_assignment;
