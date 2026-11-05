CREATE INDEX IF NOT EXISTS idx_krim_driver_assignments_accepted_by_fk
  ON public.krim_driver_assignments (accepted_by);
CREATE INDEX IF NOT EXISTS idx_krim_driver_assignments_leg_shipment_fk
  ON public.krim_driver_assignments (shipment_leg_id, shipment_id);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_doc_requirements_created_by_fk
  ON public.krim_vehicle_document_requirements (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_documents_created_by_fk
  ON public.krim_vehicle_documents (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_documents_org_fk
  ON public.krim_vehicle_documents (organization_id);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_documents_reviewed_by_fk
  ON public.krim_vehicle_documents (reviewed_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_driver_bindings_created_by_fk
  ON public.krim_vehicle_driver_bindings (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_driver_bindings_driver_profile_fk
  ON public.krim_vehicle_driver_bindings (driver_profile_id);
CREATE INDEX IF NOT EXISTS idx_krim_vehicle_driver_bindings_revoked_by_fk
  ON public.krim_vehicle_driver_bindings (revoked_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicles_created_by_fk
  ON public.krim_vehicles (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_vehicles_verified_by_fk
  ON public.krim_vehicles (verified_by);
CREATE INDEX IF NOT EXISTS idx_krim_wh_receipts_shipment_leg_fk
  ON public.krim_warehouse_receipts (shipment_leg_id, shipment_id);
CREATE INDEX IF NOT EXISTS idx_krim_wh_tasks_shipment_leg_fk
  ON public.krim_warehouse_tasks (shipment_leg_id, shipment_id);
