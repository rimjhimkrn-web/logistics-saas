CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_capacity_reservation_dispatch_identity
ON public.krim_capacity_reservations (id, shipment_id, shipment_leg_id, organization_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_capacity_binding_dispatch_identity
ON public.krim_capacity_leg_bindings (id, reservation_id, shipment_id, shipment_leg_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_partner_assignment_dispatch_identity
ON public.krim_shipment_partner_assignments
(id, shipment_id, shipment_leg_id, partner_organization_id, capacity_binding_id);

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 ADD CONSTRAINT fk_krim_dispatch_exact_partner_assignment
 FOREIGN KEY (partner_assignment_id, shipment_id, shipment_leg_id, partner_organization_id, capacity_binding_id)
 REFERENCES public.krim_shipment_partner_assignments
 (id, shipment_id, shipment_leg_id, partner_organization_id, capacity_binding_id) NOT VALID;

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 VALIDATE CONSTRAINT fk_krim_dispatch_exact_partner_assignment;

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 ADD CONSTRAINT fk_krim_dispatch_exact_capacity_binding
 FOREIGN KEY (capacity_binding_id, reservation_id, shipment_id, shipment_leg_id)
 REFERENCES public.krim_capacity_leg_bindings
 (id, reservation_id, shipment_id, shipment_leg_id) NOT VALID;

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 VALIDATE CONSTRAINT fk_krim_dispatch_exact_capacity_binding;

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 ADD CONSTRAINT fk_krim_dispatch_exact_reservation
 FOREIGN KEY (reservation_id, shipment_id, shipment_leg_id, partner_organization_id)
 REFERENCES public.krim_capacity_reservations
 (id, shipment_id, shipment_leg_id, organization_id) NOT VALID;

ALTER TABLE public.krim_shipment_leg_dispatch_authorizations
 VALIDATE CONSTRAINT fk_krim_dispatch_exact_reservation;
