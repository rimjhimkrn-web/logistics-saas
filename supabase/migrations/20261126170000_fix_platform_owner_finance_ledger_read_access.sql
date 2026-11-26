CREATE OR REPLACE FUNCTION public.krim_finance_list_revenue_ledger(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  shipment_id text,
  total_amount numeric,
  platform_commission numeric,
  partner_payout numeric,
  currency text,
  status text,
  created_at timestamptz
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.krim_organization_members m
    JOIN public.krim_organizations o ON o.id=m.organization_id
    WHERE m.user_id=v_user_id
      AND m.status='active'
      AND o.status='active'
      AND public.krim_has_permission(v_user_id,m.organization_id,'finance.view')
      AND (
        lower(coalesce(o.organization_type,''))='finance'
        OR (
          lower(coalesce(o.organization_type,''))='platform'
          AND public.krim_has_permission(v_user_id,m.organization_id,'admin.platform')
        )
      )
  ) THEN
    RAISE EXCEPTION 'Active finance.view permission in a finance organisation, or platform finance.view plus admin.platform, is required'
      USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT l.id,l.shipment_id,l.total_amount,l.platform_commission,l.partner_payout,
         l.currency,l.status,l.created_at
  FROM public.revenue_ledger l
  ORDER BY l.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit,50),1),100);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_finance_list_revenue_ledger(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_finance_list_revenue_ledger(integer) TO authenticated;

COMMENT ON FUNCTION public.krim_finance_list_revenue_ledger(integer) IS
'Read-only legacy revenue ledger for finance users; platform access requires both finance.view and admin.platform. Values are operational legacy figures and must not be represented as verified KRIM income without independent fee/invoice/payment reconciliation.';
