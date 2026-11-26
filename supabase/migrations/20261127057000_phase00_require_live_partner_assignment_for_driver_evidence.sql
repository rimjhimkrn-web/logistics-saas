-- Require a live exact partner assignment before driver evidence uploads.
-- This closes the exception-status gap: a driver assignment that remains in
-- exception state must not upload operational evidence after its partner
-- assignment has been cancelled or failed.

DROP POLICY IF EXISTS "KRIM driver evidence upload own active assignment"
ON storage.objects;

CREATE POLICY "KRIM driver evidence upload own active assignment"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'krim-driver-evidence'
  AND split_part(name, '/', 1) = (SELECT auth.uid())::text
  AND cardinality(string_to_array(name, '/')) = 3
  AND EXISTS (
    SELECT 1
    FROM public.krim_driver_assignments a
    JOIN public.krim_organization_members m
      ON m.user_id = (SELECT auth.uid())
     AND m.organization_id = a.organization_id
     AND lower(m.role) = 'driver'
     AND lower(m.status) = 'active'
    JOIN public.krim_shipment_partner_assignments pa
      ON pa.id = a.partner_assignment_id
     AND pa.shipment_id = a.shipment_id
     AND pa.shipment_leg_id = a.shipment_leg_id
     AND pa.partner_organization_id = a.organization_id
     AND pa.status IN ('accepted', 'active')
    WHERE a.id::text = split_part(name, '/', 2)
      AND a.user_id = (SELECT auth.uid())
      AND a.status NOT IN ('delivered', 'cancelled')
  )
);
