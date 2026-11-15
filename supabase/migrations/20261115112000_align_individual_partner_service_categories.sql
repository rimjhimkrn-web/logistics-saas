-- Align individual-interest categories with the public partner registration
-- selector. Interest remains non-commercial and cannot activate capabilities.
CREATE OR REPLACE FUNCTION public.krim_set_partner_account_mode(
  p_mode text,
  p_profile jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_org_id bigint;
  v_verification text;
  v_lifecycle text;
  v_profile jsonb := coalesce(p_profile, '{}'::jsonb);
  v_display_name text;
  v_country_code text;
  v_city text;
  v_service_category text;
  v_metadata_patch jsonb;
  v_partner_org_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '28000', message = 'Authentication required';
  END IF;
  IF p_mode IS NULL OR p_mode NOT IN ('development_test', 'individual_interest', 'registered_business') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Unsupported account mode';
  END IF;
  IF jsonb_typeof(v_profile) <> 'object' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'Profile must be a JSON object';
  END IF;

  SELECT count(*)::integer INTO v_partner_org_count
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id AND m.status = 'active' AND o.status = 'active'
    AND lower(coalesce(o.organization_type_code, o.organization_type)) IN
      ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator');

  IF v_partner_org_count = 0 THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'An active partner organization is required';
  ELSIF v_partner_org_count > 1 THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'Multiple active partner organizations are linked to this account. Contact KRIM support to select the correct organization.';
  END IF;

  SELECT o.id, coalesce(o.partner_verification_status, 'not_started'),
         coalesce(o.partner_lifecycle_status, 'registered')
    INTO v_org_id, v_verification, v_lifecycle
  FROM public.krim_organization_members m
  JOIN public.krim_organizations o ON o.id = m.organization_id
  WHERE m.user_id = v_user_id AND m.status = 'active' AND o.status = 'active'
    AND lower(coalesce(o.organization_type_code, o.organization_type)) IN
      ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
  FOR UPDATE OF o;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'An active partner organization is required';
  END IF;
  IF v_verification IN ('verified','approved') OR v_lifecycle IN ('approved','active') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'An approved partner organization cannot be switched into a non-commercial mode';
  END IF;

  IF p_mode = 'individual_interest' THEN
    v_display_name := nullif(btrim(v_profile->>'display_name'), '');
    v_country_code := upper(nullif(btrim(v_profile->>'country_code'), ''));
    v_city := nullif(btrim(v_profile->>'city'), '');
    v_service_category := nullif(btrim(v_profile->>'service_category'), '');

    IF v_display_name IS NULL OR char_length(v_display_name) < 2 OR char_length(v_display_name) > 120 THEN
      RAISE EXCEPTION USING errcode = '22023', message = 'Enter your name (2–120 characters)';
    END IF;
    IF v_country_code IS NULL OR v_country_code !~ '^[A-Z]{2}$' THEN
      RAISE EXCEPTION USING errcode = '22023', message = 'Choose a valid two-letter country code';
    END IF;
    IF v_city IS NULL OR char_length(v_city) < 2 OR char_length(v_city) > 120 THEN
      RAISE EXCEPTION USING errcode = '22023', message = 'Enter your operating city (2–120 characters)';
    END IF;
    IF v_service_category IS NULL OR v_service_category NOT IN (
      'road_transport','rail_freight','air_cargo','ocean_freight','multimodal',
      'freight_forwarding','warehouse','customs_support','last_mile','cross_border','other'
    ) THEN
      RAISE EXCEPTION USING errcode = '22023', message = 'Choose a supported independent-partner service category';
    END IF;

    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'individual_profile', jsonb_build_object(
        'display_name', v_display_name,
        'country_code', v_country_code,
        'city', v_city,
        'service_category', v_service_category,
        'submitted_at', now(),
        'review_status', 'interest_recorded'
      )
    );
  ELSIF p_mode = 'development_test' THEN
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now(),
      'development_test', jsonb_build_object(
        'enabled', true,
        'commercial_access', false,
        'sample_data_only', true,
        'enabled_at', now()
      )
    );
  ELSE
    v_metadata_patch := jsonb_build_object(
      'account_mode', p_mode,
      'account_mode_updated_at', now()
    );
  END IF;

  UPDATE public.krim_organizations
  SET partner_account_mode = p_mode,
      partner_metadata = (coalesce(partner_metadata, '{}'::jsonb) - 'individual_profile' - 'development_test') || v_metadata_patch,
      updated_at = now()
  WHERE id = v_org_id;

  INSERT INTO public.krim_audit_events
    (actor_user_id, organization_id, event_type, entity_type, entity_id, source, metadata, new_state)
  VALUES
    (v_user_id, v_org_id, 'partner.account_mode.selected', 'organization', v_org_id::text,
     'partner_onboarding',
     jsonb_build_object('account_mode', p_mode, 'commercial_access', false),
     jsonb_build_object('account_mode', p_mode, 'commercial_access', false));

  RETURN jsonb_build_object(
    'organization_id', v_org_id,
    'account_mode', p_mode,
    'commercial_access', false,
    'message', CASE
      WHEN p_mode = 'development_test' THEN 'Development/test mode enabled. Live commercial operations remain locked.'
      WHEN p_mode = 'individual_interest' THEN 'Independent partner interest saved. Identity and applicable operating requirements remain pending.'
      ELSE 'Registered business pathway selected. Verification remains pending until genuine documents are submitted and reviewed.'
    END
  );
END;
$function$;
