-- Harden self-service organization provisioning SECURITY DEFINER functions.
-- All application objects are schema-qualified and the search path is empty.
-- Partner provisioning now reuses one supported active partner organization,
-- recognises organization_type_code variants, and rejects ambiguous membership.
CREATE OR REPLACE FUNCTION public.krim_provision_customer_organization(p_legal_name text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_organization_id bigint;
  v_owner_role_id bigint;
  v_legal_name text := nullif(pg_catalog.btrim(p_legal_name), '');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required';
  END IF;
  IF v_legal_name IS NULL OR pg_catalog.char_length(v_legal_name) < 2 OR pg_catalog.char_length(v_legal_name) > 200 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Organization name must be between 2 and 200 characters';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('krim-customer:' || v_user_id::text)::bigint);

  SELECT o.id INTO v_organization_id
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id AND m.status = 'active'
    AND o.status = 'active'
    AND o.organization_type IN ('customer', 'enterprise')
  ORDER BY m.created_at ASC LIMIT 1;

  IF v_organization_id IS NOT NULL THEN RETURN v_organization_id; END IF;

  SELECT id INTO v_owner_role_id FROM public.krim_security_roles
  WHERE role_code = 'organization_owner' LIMIT 1;
  IF v_owner_role_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '55000', message = 'Required organization_owner role is not configured';
  END IF;

  INSERT INTO public.krim_organizations (organization_type, legal_name, display_name, status)
  VALUES ('customer', v_legal_name, v_legal_name, 'active')
  RETURNING id INTO v_organization_id;

  INSERT INTO public.krim_organization_members (organization_id, user_id, role, status)
  VALUES (v_organization_id, v_user_id, 'owner', 'active');

  INSERT INTO public.krim_user_role_assignments (user_id, organization_id, role_id, is_active, assigned_by)
  VALUES (v_user_id, v_organization_id, v_owner_role_id, true, v_user_id)
  ON CONFLICT (user_id, organization_id, role_id) DO NOTHING;

  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
  ) VALUES (
    v_user_id, v_organization_id, 'customer.organization.provisioned',
    'organization', v_organization_id::text, 'customer_onboarding',
    pg_catalog.jsonb_build_object('organization_type', 'customer')
  );
  RETURN v_organization_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_provision_partner_organization(p_legal_name text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_organization_id bigint;
  v_owner_role_id bigint;
  v_partner_role_id bigint;
  v_legal_name text := nullif(pg_catalog.btrim(p_legal_name), '');
  v_case_number text;
  v_partner_org_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required';
  END IF;
  IF v_legal_name IS NULL OR pg_catalog.char_length(v_legal_name) < 2 OR pg_catalog.char_length(v_legal_name) > 200 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Partner legal name must be between 2 and 200 characters';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('krim-partner:' || v_user_id::text)::bigint);

  SELECT count(*)::integer INTO v_partner_org_count
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id
    AND m.status = 'active'
    AND o.status = 'active'
    AND lower(coalesce(o.organization_type_code, o.organization_type, ''))
      IN ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator');

  IF v_partner_org_count > 1 THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'Multiple active partner organizations are linked to this account. Contact KRIM support to select the correct organization.';
  END IF;

  SELECT o.id INTO v_organization_id
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id
    AND m.status = 'active'
    AND o.status = 'active'
    AND lower(coalesce(o.organization_type_code, o.organization_type, ''))
      IN ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  ORDER BY m.created_at ASC
  LIMIT 1;

  IF v_organization_id IS NOT NULL THEN RETURN v_organization_id; END IF;

  SELECT id INTO v_owner_role_id FROM public.krim_security_roles WHERE role_code = 'organization_owner' LIMIT 1;
  SELECT id INTO v_partner_role_id FROM public.krim_security_roles WHERE role_code = 'partner_user' LIMIT 1;
  IF v_owner_role_id IS NULL OR v_partner_role_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '55000', message = 'Required partner RBAC roles are not configured';
  END IF;

  v_case_number := 'KPV-' || pg_catalog.upper(pg_catalog.substr(pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''), 1, 12));

  INSERT INTO public.krim_organizations (
    organization_type, organization_type_code, legal_name, display_name, status,
    partner_lifecycle_status, partner_verification_status, partner_compliance_status,
    partner_onboarding_status, partner_submitted_at
  ) VALUES (
    'partner', 'partner', v_legal_name, v_legal_name, 'active',
    'verification_pending', 'pending', 'pending', 'in_progress', pg_catalog.now()
  ) RETURNING id INTO v_organization_id;

  INSERT INTO public.krim_organization_members (organization_id, user_id, role, status)
  VALUES (v_organization_id, v_user_id, 'owner', 'active');

  INSERT INTO public.krim_user_role_assignments (user_id, organization_id, role_id, is_active, assigned_by)
  VALUES
    (v_user_id, v_organization_id, v_owner_role_id, true, v_user_id),
    (v_user_id, v_organization_id, v_partner_role_id, true, v_user_id)
  ON CONFLICT (user_id, organization_id, role_id) DO NOTHING;

  INSERT INTO public.krim_partner_verification_cases (
    organization_id, case_number, verification_level, status, submitted_by, submitted_at, metadata
  ) VALUES (
    v_organization_id, v_case_number, 'standard', 'open', v_user_id, pg_catalog.now(),
    pg_catalog.jsonb_build_object('source', 'self_service_registration')
  );

  INSERT INTO public.krim_audit_events (
    actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata
  ) VALUES (
    v_user_id, v_organization_id, 'partner.organization.registered',
    'organization', v_organization_id::text, 'partner_onboarding',
    pg_catalog.jsonb_build_object('organization_type', 'partner', 'verification_status', 'pending')
  );
  RETURN v_organization_id;
END;
$function$;
