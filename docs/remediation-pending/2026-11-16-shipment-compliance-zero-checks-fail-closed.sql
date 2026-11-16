-- KRIM remediation proposal — NOT A MIGRATION.
-- DO NOT APPLY to production until migration-history reconciliation is complete,
-- this definition is reconciled with repository source, and staging tests pass.
--
-- Finding: krim_internal_evaluate_shipment_compliance_gate(bigint) currently
-- returns status='clear' when there are zero krim_compliance_checks rows.
-- This patch changes the zero-check case to review_required (fail closed).
-- It intentionally preserves existing failed/expired/pending precedence.
--
-- Live signature inspected read-only on 2026-11-16:
-- public.krim_internal_evaluate_shipment_compliance_gate(bigint)

CREATE OR REPLACE FUNCTION public.krim_internal_evaluate_shipment_compliance_gate(
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
  v_block integer := 0;
  v_review integer := 0;
  v_expired integer := 0;
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
    count(*) FILTER (
      WHERE status IN ('failed','rejected','non_compliant','blocked')
    )::integer,
    count(*) FILTER (
      WHERE status IN ('pending','in_review','review_required')
    )::integer,
    count(*) FILTER (
      WHERE expires_at IS NOT NULL
        AND expires_at < now()
        AND status NOT IN ('failed','rejected')
    )::integer
  INTO v_total, v_block, v_review, v_expired
  FROM public.krim_compliance_checks
  WHERE shipment_id = p_shipment_id;

  IF v_block > 0 THEN
    v_status := 'blocked';
    v_reason := 'One or more compliance checks are failed, rejected, non-compliant, or blocked';
  ELSIF v_expired > 0 THEN
    v_status := 'expired';
    v_reason := 'One or more compliance checks have expired';
  ELSIF v_review > 0 THEN
    v_status := 'review_required';
    v_reason := 'One or more compliance checks require review';
  ELSIF v_total = 0 THEN
    v_status := 'review_required';
    v_reason := 'No shipment compliance checks are recorded; clearance cannot be inferred';
  ELSE
    v_status := 'clear';
    v_reason := NULL;
  END IF;

  INSERT INTO public.krim_shipment_compliance_gates
    (shipment_id,status,risk_level,blocking_reason,checked_at,metadata)
  VALUES
    (
      p_shipment_id,
      v_status,
      CASE
        WHEN v_status = 'blocked' THEN 'high'
        WHEN v_status IN ('expired','review_required') THEN 'medium'
        ELSE 'low'
      END,
      v_reason,
      now(),
      jsonb_build_object(
        'total_checks',v_total,
        'blocked_checks',v_block,
        'review_checks',v_review,
        'expired_checks',v_expired,
        'zero_check_fail_closed',v_total=0
      )
    )
  ON CONFLICT (shipment_id) DO UPDATE
    SET status = EXCLUDED.status,
        risk_level = EXCLUDED.risk_level,
        blocking_reason = EXCLUDED.blocking_reason,
        checked_at = EXCLUDED.checked_at,
        metadata = EXCLUDED.metadata,
        updated_at = now();

  RETURN jsonb_build_object(
    'ok',true,
    'shipment_id',p_shipment_id,
    'status',v_status,
    'total_checks',v_total,
    'blocked_checks',v_block,
    'review_checks',v_review,
    'expired_checks',v_expired,
    'blocking_reason',v_reason
  );
END;
$function$;

-- Staging-only verification matrix (run only with synthetic shipment/check rows):
-- 1. No checks => review_required, zero_check_fail_closed=true.
-- 2. One pending check => review_required.
-- 3. One failed/rejected/blocked check => blocked.
-- 4. One expired check => expired.
-- 5. Complete non-expired, accepted check set => preserve existing clear behavior.
-- 6. Missing shipment => shipment_not_found.
-- Also verify caller ACL/EXECUTE grants and SECURITY DEFINER ownership/search_path
-- against the reconciled canonical definition before deployment.
