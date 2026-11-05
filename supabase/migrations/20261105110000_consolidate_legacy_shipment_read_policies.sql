DROP POLICY IF EXISTS "Customers can view own delivery proofs" ON public.delivery_proofs;
DROP POLICY IF EXISTS "Partners can view own delivery proofs" ON public.delivery_proofs;
CREATE POLICY "KRIM delivery proofs scoped read"
ON public.delivery_proofs FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.shipment_requests s
    WHERE s.id=delivery_proofs.shipment_id AND s.customer_id=(SELECT auth.uid())
  )
  OR partner_id=(
    SELECT partners.id FROM public.partners
    WHERE partners.user_id=(SELECT auth.uid()) LIMIT 1
  )
);

DROP POLICY IF EXISTS "Customers can view own shipments" ON public.shipment_requests;
DROP POLICY IF EXISTS "Partners can view assigned shipments" ON public.shipment_requests;
CREATE POLICY "KRIM legacy shipment requests scoped read"
ON public.shipment_requests FOR SELECT TO authenticated
USING (
  customer_id=(SELECT auth.uid())
  OR partner_id=(
    SELECT partners.id FROM public.partners
    WHERE partners.user_id=(SELECT auth.uid()) LIMIT 1
  )
);
