CREATE OR REPLACE FUNCTION public.krim_finance_list_payment_webhook_events(
  p_only_unprocessed boolean DEFAULT true,
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  event_reference text,
  event_type text,
  processed boolean,
  created_at timestamptz,
  processed_at timestamptz,
  order_reference text,
  matched_order_status text,
  reconciliation_state text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;
  IF COALESCE((SELECT auth.jwt())->>'aal','aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'AAL2 authentication is required for payment webhook reconciliation' USING ERRCODE='42501';
  END IF;
  IF NOT public.krim_has_permission(v_user_id,1::bigint,'admin.platform') THEN
    RAISE EXCEPTION 'Platform administrator permission is required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH event_refs AS (
    SELECT
      e.event_id,
      e.event_type,
      e.processed,
      e.created_at,
      e.processed_at,
      COALESCE(
        NULLIF(e.payload #>> '{payload,payment,entity,order_id}',''),
        NULLIF(e.payload #>> '{payload,order,entity,id}','')
      ) AS provider_order_id
    FROM public.payment_webhook_events e
    WHERE (NOT COALESCE(p_only_unprocessed,true) OR e.processed=false)
  )
  SELECT
    left(e.event_id,8)||'…'||right(e.event_id,4),
    e.event_type,
    e.processed,
    e.created_at,
    e.processed_at,
    CASE WHEN e.provider_order_id IS NULL THEN NULL
      ELSE left(e.provider_order_id,8)||'…'||right(e.provider_order_id,4) END,
    po.status,
    CASE
      WHEN po.id IS NULL THEN 'UNMATCHED_ORDER'
      WHEN e.processed THEN 'PROCESSED'
      ELSE 'MATCHED_UNPROCESSED'
    END
  FROM event_refs e
  LEFT JOIN LATERAL (
    SELECT p.id,p.status
    FROM public.payment_orders p
    WHERE p.payment_provider='razorpay'
      AND p.razorpay_order_id=e.provider_order_id
    ORDER BY p.created_at DESC
    LIMIT 1
  ) po ON true
  ORDER BY e.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit,100),1),100);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_finance_list_payment_webhook_events(boolean,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_finance_list_payment_webhook_events(boolean,integer) TO authenticated;
COMMENT ON FUNCTION public.krim_finance_list_payment_webhook_events(boolean,integer) IS
  'AAL2 platform-admin-only read-only view of masked Razorpay webhook metadata and local order match state; never returns raw payloads or mutates events.';
