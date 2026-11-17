-- Restore authenticated execution for the customer shipment journey.
-- Every exposed RPC below performs its own auth.uid() and organization/permission checks.
-- The prepare wrapper is SECURITY DEFINER so it can invoke the deliberately non-public
-- award helper; the helper itself revalidates the caller's identity and permissions.

CREATE OR REPLACE FUNCTION public.krim_customer_prepare_partner_quote(
  p_partner_quote_id bigint,
  p_valid_until timestamp with time zone DEFAULT (now() + interval '7 days')
)
RETURNS public.krim_quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000', message='Authentication required';
  END IF;
  RETURN public.krim_award_partner_quote_for_checkout(p_partner_quote_id,p_valid_until);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_create_global_shipment_idempotent(bigint,jsonb,jsonb,text,numeric,text,text,uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_customer_list_partner_quotes(bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_customer_list_partner_quotes(bigint[]) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_customer_prepare_partner_quote(bigint,timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_customer_prepare_partner_quote(bigint,timestamp with time zone) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_accept_global_quote(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_accept_global_quote(bigint) TO authenticated;

REVOKE ALL ON FUNCTION public.krim_get_shipment_tracking(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_get_shipment_tracking(text) TO authenticated;
