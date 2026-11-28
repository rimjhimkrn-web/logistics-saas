-- Disposable PostgreSQL fixture only. Never run against KRIM staging or production.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END
$roles$;

CREATE OR REPLACE FUNCTION public.krim_partner_register_capacity_resource(
  bigint,text,text,bigint,bigint,numeric,text,text,
  timestamp with time zone,timestamp with time zone,text[],text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- Source-shape guard fixtures: auth.uid(), krim_has_permission,
  -- krim_partner_compliance_is_current, storage.objects,
  -- pending_review, unavailable.
  RETURN 1;
END
$function$;

REVOKE ALL ON FUNCTION public.krim_partner_register_capacity_resource(
  bigint,text,text,bigint,bigint,numeric,text,text,
  timestamp with time zone,timestamp with time zone,text[],text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.krim_partner_register_capacity_resource(
  bigint,text,text,bigint,bigint,numeric,text,text,
  timestamp with time zone,timestamp with time zone,text[],text
) TO service_role;
