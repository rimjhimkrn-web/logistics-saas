DO $$
BEGIN
 IF (SELECT count(*) FROM public.krim_security_permissions) <> 23 THEN
   RAISE EXCEPTION 'Expected exactly 23 permission definitions';
 END IF;
 IF (SELECT count(*) FROM public.krim_role_permissions) <> 155 THEN
   RAISE EXCEPTION 'Expected exactly 155 role-permission mappings';
 END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.krim_role_permissions rp
   JOIN public.krim_security_roles r ON r.id=rp.role_id
   JOIN public.krim_security_permissions p ON p.id=rp.permission_id
   WHERE r.role_code='organization_owner' AND p.permission_code='partner.manage' AND rp.granted
 ) THEN RAISE EXCEPTION 'organization_owner partner.manage mapping missing'; END IF;
 IF EXISTS (
   SELECT 1 FROM public.krim_role_permissions rp
   JOIN public.krim_security_roles r ON r.id=rp.role_id
   JOIN public.krim_security_permissions p ON p.id=rp.permission_id
   WHERE r.role_code='customer_user' AND p.permission_code='partner.manage' AND rp.granted
 ) THEN RAISE EXCEPTION 'customer_user unexpectedly received partner.manage'; END IF;
END $$;
