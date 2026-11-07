-- KRIM partner quote RPC staging preflight
-- REVIEW-ONLY / READ-ONLY. Run against STAGING before applying the proposed RPC.
-- This script does not create objects, write rows, or change grants.

DO $preflight$
DECLARE
  v_missing text[] := ARRAY[]::text[];
  v_rpc regprocedure;
  v_owner oid;
BEGIN
  IF to_regclass('public.krim_partner_quotes') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_partner_quotes');
  END IF;
  IF to_regclass('public.krim_partner_opportunities') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_partner_opportunities');
  END IF;
  IF to_regclass('public.krim_organizations') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_organizations');
  END IF;
  IF to_regclass('public.krim_organization_members') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_organization_members');
  END IF;
  IF to_regclass('public.krim_partner_capabilities') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_partner_capabilities');
  END IF;
  IF to_regclass('public.krim_currencies') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_currencies');
  END IF;
  IF to_regclass('public.krim_audit_events') IS NULL THEN
    v_missing := array_append(v_missing, 'public.krim_audit_events');
  END IF;

  IF cardinality(v_missing) > 0 THEN
    RAISE EXCEPTION 'Missing required relations: %', array_to_string(v_missing, ', ');
  END IF;

  IF to_regprocedure('private.krim_has_permission(uuid,bigint,text)') IS NULL THEN
    RAISE EXCEPTION 'Missing private.krim_has_permission(uuid,bigint,text)';
  END IF;
  IF to_regprocedure('private.krim_partner_capability_covers_shipment(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'Missing private.krim_partner_capability_covers_shipment(bigint,bigint)';
  END IF;

  v_rpc := to_regprocedure(
    'public.krim_submit_partner_quote_for_organization(bigint,bigint,numeric,text,timestamp with time zone,text)'
  );
  IF v_rpc IS NOT NULL THEN
    SELECT proowner INTO v_owner FROM pg_proc WHERE oid = v_rpc;
    IF NOT has_function_privilege(v_owner, 'private.krim_partner_capability_covers_shipment(bigint,bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION 'RPC owner cannot execute private capability helper';
    END IF;
    IF has_function_privilege('anon', v_rpc, 'EXECUTE') THEN
      RAISE EXCEPTION 'anon unexpectedly has EXECUTE on proposed RPC';
    END IF;
    IF NOT has_function_privilege('authenticated', v_rpc, 'EXECUTE') THEN
      RAISE EXCEPTION 'authenticated lacks EXECUTE on proposed RPC';
    END IF;
  END IF;
END;
$preflight$;

-- Confirm required columns exist (zero rows means an expected column is missing).
WITH expected(table_name, column_name) AS (
  VALUES
    ('krim_organization_members','organization_id'),
    ('krim_organization_members','user_id'),
    ('krim_organization_members','status'),
    ('krim_organizations','organization_type'),
    ('krim_organizations','status'),
    ('krim_organizations','partner_account_mode'),
    ('krim_organizations','partner_verification_status'),
    ('krim_organizations','partner_lifecycle_status'),
    ('krim_organizations','partner_compliance_status'),
    ('krim_partner_capabilities','organization_id'),
    ('krim_partner_capabilities','active'),
    ('krim_partner_capabilities','verification_status'),
    ('krim_partner_capabilities','effective_from'),
    ('krim_partner_capabilities','effective_until'),
    ('krim_partner_opportunities','shipment_id'),
    ('krim_partner_opportunities','customer_organization_id'),
    ('krim_partner_opportunities','status'),
    ('krim_partner_opportunities','response_deadline'),
    ('krim_partner_opportunities','awarded_partner_organization_id'),
    ('krim_partner_quotes','opportunity_id'),
    ('krim_partner_quotes','shipment_id'),
    ('krim_partner_quotes','partner_organization_id'),
    ('krim_partner_quotes','quote_number'),
    ('krim_partner_quotes','amount'),
    ('krim_partner_quotes','currency_code'),
    ('krim_partner_quotes','valid_until'),
    ('krim_partner_quotes','status'),
    ('krim_partner_quotes','submitted_at'),
    ('krim_partner_quotes','pricing_snapshot'),
    ('krim_partner_quotes','metadata'),
    ('krim_currencies','code'),
    ('krim_currencies','is_active'),
    ('krim_audit_events','actor_user_id'),
    ('krim_audit_events','organization_id'),
    ('krim_audit_events','event_type'),
    ('krim_audit_events','entity_type'),
    ('krim_audit_events','entity_id'),
    ('krim_audit_events','source'),
    ('krim_audit_events','metadata')
)
SELECT e.table_name, e.column_name AS missing_column
FROM expected e
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name = e.table_name
 AND c.column_name = e.column_name
WHERE c.column_name IS NULL
ORDER BY e.table_name, e.column_name;

-- Review function owner and ACL after the proposed migration is applied in staging.
SELECT
  p.oid::regprocedure AS function_signature,
  pg_get_userbyid(p.proowner) AS function_owner,
  p.prosecdef AS security_definer,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
  EXISTS (
    SELECT 1
    FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
    WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
  ) AS public_can_execute
FROM pg_proc p
WHERE p.oid = to_regprocedure(
  'public.krim_submit_partner_quote_for_organization(bigint,bigint,numeric,text,timestamp with time zone,text)'
);

-- Authenticated integration tests are intentionally separate from this preflight:
-- use two real staging partner organizations and distinct authenticated users.
-- Verify org isolation, permission denial, all eligibility gates, expired/awarded
-- opportunities, duplicate submissions, concurrency, quote/audit consistency,
-- and that customer/driver roles cannot call the RPC without partner permission.
