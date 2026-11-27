-- Storage policies are permissive by default and are OR-combined.
-- The previous AAL2 INSERT policy was permissive, so it could independently
-- authorize any authenticated AAL2 user to insert arbitrary objects in this
-- bucket, bypassing the separate organization/uploader path policy.
-- Convert it to a restrictive policy so AAL2 is ANDed with every applicable
-- permissive ownership/organization policy.
DROP POLICY IF EXISTS "krim_partner_verification_upload_require_aal2"
ON storage.objects;

CREATE POLICY "krim_partner_verification_upload_require_aal2"
ON storage.objects
AS RESTRICTIVE
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'krim-partner-verification'
  AND COALESCE(auth.jwt()->>'aal', 'aal1') = 'aal2'
);
