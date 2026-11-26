INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'krim-driver-evidence',
  'krim-driver-evidence',
  false,
  10485760,
  ARRAY['image/jpeg','image/png','image/webp','application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "KRIM driver evidence upload own active assignment" ON storage.objects;
CREATE POLICY "KRIM driver evidence upload own active assignment"
ON storage.objects FOR INSERT TO authenticated
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
    WHERE a.id::text = split_part(name, '/', 2)
      AND a.user_id = (SELECT auth.uid())
      AND a.status NOT IN ('delivered','cancelled')
  )
);

DROP POLICY IF EXISTS "KRIM driver evidence read own assignment" ON storage.objects;
CREATE POLICY "KRIM driver evidence read own assignment"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'krim-driver-evidence'
  AND (
    (
      split_part(name, '/', 1) = (SELECT auth.uid())::text
      AND cardinality(string_to_array(name, '/')) = 3
      AND EXISTS (
        SELECT 1
        FROM public.krim_driver_assignments a
        JOIN public.krim_organization_members m
          ON m.user_id = (SELECT auth.uid())
         AND m.organization_id = a.organization_id
         AND lower(m.role) = 'driver'
         AND lower(m.status) = 'active'
        WHERE a.id::text = split_part(name, '/', 2)
          AND a.user_id = (SELECT auth.uid())
      )
    )
    OR (
      COALESCE(auth.jwt()->>'aal','aal1') = 'aal2'
      AND private.krim_has_permission((SELECT auth.uid()), 1, 'admin.platform')
    )
  )
);

REVOKE UPDATE, DELETE ON storage.objects FROM authenticated;

