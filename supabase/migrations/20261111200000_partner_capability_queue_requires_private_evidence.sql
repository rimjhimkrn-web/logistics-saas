-- Keep the privileged partner-capability review queue limited to submissions
-- with verifiable, partner-owned capability evidence. Onboarding declarations
-- without capability evidence remain pending but are not actionable decisions.
CREATE OR REPLACE FUNCTION public.krim_admin_list_partner_capabilities()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_items jsonb;
  v_incomplete_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  IF coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' THEN
    RAISE EXCEPTION USING errcode='42501', message='Multi-factor authentication required';
  END IF;
  IF NOT private.krim_has_permission(v_user_id, 1::bigint, 'admin.platform') THEN
    RAISE EXCEPTION USING errcode='42501', message='Platform administrator permission required';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'organization_id',c.organization_id,
    'organization_name',coalesce(o.display_name,o.legal_name),
    'organization_type',coalesce(o.organization_type_code,o.organization_type),
    'organization_status',o.status,'partner_account_mode',o.partner_account_mode,
    'partner_lifecycle_status',o.partner_lifecycle_status,
    'partner_verification_status',o.partner_verification_status,
    'partner_compliance_status',o.partner_compliance_status,
    'transport_mode_id',c.transport_mode_id,'transport_mode_name',tm.name,
    'transport_mode_code',tm.code,'service_type',c.service_type,
    'coverage_country_id',c.coverage_country_id,'coverage_country_name',co.name,
    'coverage_country_iso2',co.iso2,'coverage_region',c.coverage_region,
    'max_weight_kg',c.max_weight_kg,'refrigerated',c.refrigerated,
    'hazardous_goods_capable',c.hazardous_goods_capable,'active',c.active,
    'verification_status',c.verification_status,'created_at',c.created_at,
    'effective_from',c.effective_from,'effective_until',c.effective_until,
    'metadata',c.metadata
  ) ORDER BY c.created_at ASC,c.id ASC),'[]'::jsonb)
  INTO v_items
  FROM public.krim_partner_capabilities c
  JOIN public.krim_organizations o ON o.id=c.organization_id
  LEFT JOIN public.krim_transport_modes tm ON tm.id=c.transport_mode_id
  LEFT JOIN public.krim_countries co ON co.id=c.coverage_country_id
  WHERE c.verification_status='pending'
    AND CASE
      WHEN jsonb_typeof(c.metadata->'evidence_paths')='array'
       AND jsonb_array_length(c.metadata->'evidence_paths') BETWEEN 1 AND 5
       AND coalesce(c.metadata->>'submitted_by','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      THEN NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(c.metadata->'evidence_paths') AS e(path)
        WHERE e.path !~ ('^'||c.organization_id::text||'/'||(c.metadata->>'submitted_by')||'/capability/[A-Za-z0-9._-]{1,120}$')
           OR NOT EXISTS (
             SELECT 1 FROM storage.objects so
             WHERE so.bucket_id='krim-partner-verification'
               AND so.name=e.path
               AND so.owner::text=(c.metadata->>'submitted_by')
           )
      )
      ELSE false
    END;

  SELECT count(*)::integer
  INTO v_incomplete_count
  FROM public.krim_partner_capabilities c
  WHERE c.verification_status='pending'
    AND NOT (
      CASE
        WHEN jsonb_typeof(c.metadata->'evidence_paths')='array'
         AND jsonb_array_length(c.metadata->'evidence_paths') BETWEEN 1 AND 5
         AND coalesce(c.metadata->>'submitted_by','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        THEN NOT EXISTS (
          SELECT 1
          FROM jsonb_array_elements_text(c.metadata->'evidence_paths') AS e(path)
          WHERE e.path !~ ('^'||c.organization_id::text||'/'||(c.metadata->>'submitted_by')||'/capability/[A-Za-z0-9._-]{1,120}$')
             OR NOT EXISTS (
               SELECT 1 FROM storage.objects so
               WHERE so.bucket_id='krim-partner-verification'
                 AND so.name=e.path
                 AND so.owner::text=(c.metadata->>'submitted_by')
             )
        )
        ELSE false
      END
    );

  RETURN jsonb_build_object(
    'items',v_items,
    'count',jsonb_array_length(v_items),
    'incomplete_count',v_incomplete_count
  );
END;
$function$;
