-- Isolated PostgreSQL 16 fixture for the proposed country-pack column-reference repair.
CREATE TABLE public.krim_country_operating_packs (
  id bigint PRIMARY KEY,
  pack_status text NOT NULL,
  next_review_at timestamptz
);
INSERT INTO public.krim_country_operating_packs(id,pack_status,next_review_at)
VALUES (1,'approved',now()+interval '30 days');

CREATE OR REPLACE FUNCTION public.krim_admin_review_partner_service_area(
  p_service_area_id bigint,p_decision text,p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.krim_country_operating_packs cp
    WHERE cp.status='approved'
      AND (cp.next_review_at IS NULL OR cp.next_review_at>now())
  ) THEN
    RETURN jsonb_build_object('approved',false);
  END IF;
  RETURN jsonb_build_object('approved',true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.krim_admin_review_partner_service_area(bigint,text,text) TO authenticated;
