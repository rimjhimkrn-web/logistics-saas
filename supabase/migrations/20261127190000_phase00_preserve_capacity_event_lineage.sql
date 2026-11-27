ALTER TABLE public.krim_capacity_reservation_events
  ADD CONSTRAINT krim_capacity_reservation_events_reservation_fk
  FOREIGN KEY (reservation_id)
  REFERENCES public.krim_capacity_reservations(id)
  ON DELETE RESTRICT;

ALTER TABLE public.krim_capacity_leg_binding_events
  ADD CONSTRAINT krim_capacity_leg_binding_events_binding_fk
  FOREIGN KEY (binding_id)
  REFERENCES public.krim_capacity_leg_bindings(id)
  ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_krim_capacity_reservation_events_reservation_id
  ON public.krim_capacity_reservation_events(reservation_id, event_time, id);

CREATE INDEX IF NOT EXISTS idx_krim_capacity_leg_binding_events_binding_id
  ON public.krim_capacity_leg_binding_events(binding_id, event_time, id);