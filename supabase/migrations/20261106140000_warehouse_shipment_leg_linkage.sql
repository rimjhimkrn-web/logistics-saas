-- Link warehouse tasks and receipts to the authoritative shipment and leg.
-- Nullable for legacy/manual warehouse workflows; linked rows are protected by
-- a composite FK so the selected leg must belong to the selected shipment.

ALTER TABLE public.krim_shipment_legs
  ADD CONSTRAINT krim_shipment_legs_id_shipment_uk UNIQUE (id, shipment_id);

ALTER TABLE public.krim_warehouse_tasks
  ADD COLUMN IF NOT EXISTS shipment_id bigint,
  ADD COLUMN IF NOT EXISTS shipment_leg_id bigint;

ALTER TABLE public.krim_warehouse_receipts
  ADD COLUMN IF NOT EXISTS shipment_leg_id bigint;

ALTER TABLE public.krim_warehouse_tasks
  ADD CONSTRAINT krim_wh_tasks_shipment_leg_fk
  FOREIGN KEY (shipment_leg_id, shipment_id)
  REFERENCES public.krim_shipment_legs (id, shipment_id)
  ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE public.krim_warehouse_receipts
  ADD CONSTRAINT krim_wh_receipts_shipment_leg_fk
  FOREIGN KEY (shipment_leg_id, shipment_id)
  REFERENCES public.krim_shipment_legs (id, shipment_id)
  ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE public.krim_warehouse_tasks
  ADD CONSTRAINT krim_wh_tasks_leg_requires_shipment_ck
  CHECK (shipment_leg_id IS NULL OR shipment_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS krim_wh_tasks_shipment_leg_idx
  ON public.krim_warehouse_tasks (shipment_id, shipment_leg_id)
  WHERE shipment_leg_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS krim_wh_receipts_shipment_leg_idx
  ON public.krim_warehouse_receipts (shipment_id, shipment_leg_id)
  WHERE shipment_leg_id IS NOT NULL;
