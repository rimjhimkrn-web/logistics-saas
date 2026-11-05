-- Align private partner evidence upload/read access with the full set of
-- registered-business partner organization types accepted by onboarding and
-- capacity registration. Ownership remains bound to active org membership;
-- uploads remain bound to the authenticated user's own org-folder path.

DROP POLICY IF EXISTS krim_partner_verification_read_own_org ON storage.objects;
CREATE POLICY krim_partner_verification_read_own_org
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id='krim-partner-verification'
  AND CASE
    WHEN split_part(name,'/',1) ~ '^[0-9]+$' THEN EXISTS (
      SELECT 1
      FROM public.krim_organization_members m
      JOIN public.krim_organizations o ON o.id=m.organization_id
      WHERE m.user_id=(SELECT auth.uid())
        AND m.status='active'
        AND m.organization_id=split_part(storage.objects.name,'/',1)::bigint
        AND coalesce(o.organization_type_code,o.organization_type) IN
          ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
    )
    ELSE false
  END
);

DROP POLICY IF EXISTS krim_partner_verification_upload_own_org ON storage.objects;
CREATE POLICY krim_partner_verification_upload_own_org
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id='krim-partner-verification'
  AND split_part(name,'/',2)=(SELECT auth.uid())::text
  AND CASE
    WHEN split_part(name,'/',1) ~ '^[0-9]+$' THEN EXISTS (
      SELECT 1
      FROM public.krim_organization_members m
      JOIN public.krim_organizations o ON o.id=m.organization_id
      WHERE m.user_id=(SELECT auth.uid())
        AND m.status='active'
        AND m.organization_id=split_part(storage.objects.name,'/',1)::bigint
        AND coalesce(o.organization_type_code,o.organization_type) IN
          ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
    )
    ELSE false
  END
);
