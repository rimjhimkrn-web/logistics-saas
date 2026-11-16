-- KRIM remediation proposal — NOT A MIGRATION.
-- DO NOT APPLY to production until migration-history reconciliation is complete,
-- canonical source/schema are reconciled, and synthetic staging tests pass.
--
-- Finding: krim_internal_evaluate_shipment_document_gate(bigint) returns
-- status='clear' when there are zero required document rows. Live production
-- currently has zero rows in krim_shipment_document_requirements, so the
-- current evaluator can infer clearance without any configured requirements.
--
-- Conservative correction: zero required rows => review_required. This does
-- not invent jurisdiction-specific document requirements. A separate validated
-- requirement-generation policy must populate requirements from cargo, route,
-- transport mode, countries and applicable law before a shipment can clear.

CREATE OR REPLACE FUNCTION public.krim_internal_evaluate_shipment_document_gate(
  p_shipment_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_shipment public.krim_shipments%rowtype;
  v_total integer := 0;
  v_missing integer := 0;
  v_expired integer := 0;
  v_rejected integer := 0;
  v_status text;
  v_reason text;
BEGIN
  SELECT *
    INTO v_shipment
    FROM public.krim_shipments
   WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment_not_found';
  END IF;

  SELECT
    count(*)::integer,
    count(*) FILTER (WHERE status IN ('missing','submitted'))::integer,
    count(*) FILTER (WHERE status='expired')::integer,
    count(*) FILTER (WHERE status='rejected')::integer
  INTO v_total,v_missing,v_expired,v_rejected
  FROM public.krim_shipment_document_requirements
  WHERE shipment_id=p_shipment_id
    AND required=true;

  IF v_rejected > 0 THEN
    v_status := 'blocked';
    v_reason := 'One or more required shipment documents were rejected';
  ELSIF v_expired > 0 THEN
    v_status := 'expired';
    v_reason := 'One or more required shipment documents are expired';
  ELSIF v_missing > 0 THEN
    v_status := 'incomplete';
    v_reason := 'One or more required shipment documents are missing or not yet verified';
  ELSIF v_total = 0 THEN
    v_status := 'review_required';
    v_reason := 'No required shipment documents are configured; document clearance cannot be inferred';
  ELSE
    v_status := 'clear';
    v_reason := NULL;
  END IF;

  RETURN jsonb_build_object(
    'ok',true,
    'shipment_id',p_shipment_id,
    'status',v_status,
    'reason',v_reason,
    'required_documents',v_total,
    'missing_or_unverified',v_missing,
    'expired',v_expired,
    'rejected',v_rejected
  );
END;
$function$;

-- Synthetic staging verification:
-- 1. Shipment with no requirement rows => review_required.
-- 2. Only non-required rows => review_required.
-- 3. Required missing/submitted row => incomplete.
-- 4. Required expired row => expired.
-- 5. Required rejected row => blocked.
-- 6. Required, non-expired rows in verified/satisfied states => clear.
-- 7. Missing shipment => shipment_not_found.
-- Confirm SECURITY DEFINER owner, ACL, callers and downstream readiness
-- semantics against reconciled production definitions before any deployment.
