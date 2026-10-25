-- Cover foreign-key lookups flagged by the Supabase performance advisor.
CREATE INDEX IF NOT EXISTS idx_private_payment_transactions_customer_id ON private.krim_payment_transactions (customer_id);
CREATE INDEX IF NOT EXISTS idx_private_payment_transactions_partner_quote_id ON private.krim_payment_transactions (partner_quote_id);
CREATE INDEX IF NOT EXISTS idx_private_payment_transactions_quote_id ON private.krim_payment_transactions (quote_id);
CREATE INDEX IF NOT EXISTS idx_krim_driver_assignments_created_by ON public.krim_driver_assignments (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_driver_assignments_shipment_dispatch_id ON public.krim_driver_assignments (shipment_dispatch_id);
CREATE INDEX IF NOT EXISTS idx_krim_driver_assignments_shipment_id ON public.krim_driver_assignments (shipment_id);
CREATE INDEX IF NOT EXISTS idx_krim_driver_delivery_evidence_user_id ON public.krim_driver_delivery_evidence (user_id);
CREATE INDEX IF NOT EXISTS idx_krim_driver_profiles_organization_id ON public.krim_driver_profiles (organization_id);
CREATE INDEX IF NOT EXISTS idx_krim_driver_trip_events_user_id ON public.krim_driver_trip_events (user_id);
CREATE INDEX IF NOT EXISTS idx_krim_inquiry_followups_created_by ON public.krim_inquiry_followups (created_by);
CREATE INDEX IF NOT EXISTS idx_krim_warehouse_inventory_movements_facility_id ON public.krim_warehouse_inventory_movements (facility_id);
CREATE INDEX IF NOT EXISTS idx_krim_warehouse_inventory_movements_inventory_fk ON public.krim_warehouse_inventory_movements (inventory_id);
CREATE INDEX IF NOT EXISTS idx_krim_warehouse_receipts_shipment_id ON public.krim_warehouse_receipts (shipment_id);