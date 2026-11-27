-- Phase 00 hardening: keep the exposed RPC SECURITY INVOKER.
-- Privileged row filtering lives in a non-exposed private-schema function with explicit auth checks.

CREATE OR REPLACE FUNCTION private.krim_get_partner_response_evidence_scoped(
  p_quote_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  event_id bigint,
  quote_id bigint,
  event_type text,
  previous_status text,
  new_status text,
  event_time timestamptz,
  shipment_id bigint,
  partner_organization_id bigint,
  partner_quote_id bigint,
  assignment_id bigint,
  assignment_number text,
  capacity_binding_id bigint,
  evidence_scope text,
  partner_quote_snapshot jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501',
      message = 'Authentication is required to read partner response evidence';
  END IF;

  RETURN QUERY
  SELECT
    e.id, e.quote_id, e.event_type, e.previous_status, e.new_status, e.event_time,
    NULLIF(e.payload ->> 'shipment_id', '')::bigint,
    NULLIF(e.payload ->> 'partner_organization_id', '')::bigint,
    NULLIF(e.payload ->> 'partner_quote_id', '')::bigint,
    NULLIF(e.payload ->> 'assignment_id', '')::bigint,
    e.payload ->> 'assignment_number',
    NULLIF(e.payload ->> 'capacity_binding_id', '')::bigint,
    'partner_response_record_not_a_signed_contract'::text,
    CASE WHEN EXISTS (
      SELECT 1 FROM public.krim_organization_members pm
      WHERE pm.user_id = v_user_id
        AND pm.organization_id = NULLIF(e.payload ->> 'partner_organization_id', '')::bigint
        AND pm.status = 'active'
    ) THEN e.payload -> 'partner_quote_snapshot' ELSE NULL END
  FROM public.krim_quote_events e
  JOIN public.krim_quotes q ON q.id = e.quote_id
  WHERE e.event_type IN ('partner.quote_accepted', 'partner.quote_rejected')
    AND (p_quote_id IS NULL OR e.quote_id = p_quote_id)
    AND (
      EXISTS (
        SELECT 1 FROM public.krim_organization_members cm
        WHERE cm.user_id = v_user_id
          AND cm.organization_id = q.customer_organization_id
          AND cm.status = 'active'
      )
      OR EXISTS (
        SELECT 1 FROM public.krim_organization_members pm
        WHERE pm.user_id = v_user_id
          AND pm.organization_id = NULLIF(e.payload ->> 'partner_organization_id', '')::bigint
          AND pm.status = 'active'
      )
    )
  ORDER BY e.event_time DESC, e.id DESC
  LIMIT v_limit;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_get_partner_response_evidence_scoped(bigint, integer)
FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.krim_get_partner_response_evidence_scoped(bigint, integer)
TO authenticated;

CREATE OR REPLACE FUNCTION public.krim_get_partner_response_evidence(
  p_quote_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  event_id bigint,
  quote_id bigint,
  event_type text,
  previous_status text,
  new_status text,
  event_time timestamptz,
  shipment_id bigint,
  partner_organization_id bigint,
  partner_quote_id bigint,
  assignment_id bigint,
  assignment_number text,
  capacity_binding_id bigint,
  evidence_scope text,
  partner_quote_snapshot jsonb
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT *
  FROM private.krim_get_partner_response_evidence_scoped(p_quote_id, p_limit);
$function$;

REVOKE ALL ON FUNCTION public.krim_get_partner_response_evidence(bigint, integer)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_get_partner_response_evidence(bigint, integer)
TO authenticated;

COMMENT ON FUNCTION public.krim_get_partner_response_evidence(bigint, integer)
IS 'Organisation-scoped partner response evidence RPC. Invoker wrapper; internal private function checks active organisation membership. Partner quote snapshot is visible only to members of that partner organisation. Evidence is not a signed contract.';
