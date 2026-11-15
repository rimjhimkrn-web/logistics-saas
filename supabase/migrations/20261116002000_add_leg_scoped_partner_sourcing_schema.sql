-- Add explicit shipment-leg scope to partner sourcing records without opening
-- the legacy shipment-wide quote workflow for multi-leg shipments.
ALTER TABLE public.krim_partner_opportunities
  ADD COLUMN IF NOT EXISTS shipment_leg_id bigint
  REFERENCES public.krim_shipment_legs(id) ON DELETE RESTRICT;

ALTER TABLE public.krim_partner_quotes
  ADD COLUMN IF NOT EXISTS shipment_leg_id bigint
  REFERENCES public.krim_shipment_legs(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_krim_partner_opportunities_shipment_leg
  ON public.krim_partner_opportunities(shipment_id, shipment_leg_id)
  WHERE shipment_leg_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_krim_partner_quotes_shipment_leg
  ON public.krim_partner_quotes(shipment_id, shipment_leg_id, opportunity_id)
  WHERE shipment_leg_id IS NOT NULL;

CREATE OR REPLACE FUNCTION private.krim_validate_leg_scoped_partner_opportunity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_leg public.krim_shipment_legs%rowtype;
  v_plan public.krim_shipment_leg_plans%rowtype;
BEGIN
  IF NEW.shipment_leg_id IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT * INTO v_leg FROM public.krim_shipment_legs
  WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id
  FOR KEY SHARE;
  IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='23514',
      MESSAGE='Leg-scoped opportunity must reference a plan-linked leg of the same shipment';
  END IF;
  SELECT p.* INTO v_plan
  FROM public.krim_shipment_leg_plans p
  JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
  WHERE p.shipment_id=NEW.shipment_id AND p.status='active'
    AND pi.id=v_leg.leg_plan_item_id
  ORDER BY p.plan_version DESC LIMIT 1
  FOR KEY SHARE OF p;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23514',
      MESSAGE='Leg-scoped opportunity requires an active route-plan item';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_validate_leg_scoped_partner_quote()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_leg public.krim_shipment_legs%rowtype;
BEGIN
  SELECT * INTO v_opportunity FROM public.krim_partner_opportunities
  WHERE id=NEW.opportunity_id AND shipment_id=NEW.shipment_id
  FOR KEY SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23503',
      MESSAGE='Partner quote must reference an opportunity for the same shipment';
  END IF;
  IF NEW.shipment_leg_id IS DISTINCT FROM v_opportunity.shipment_leg_id THEN
    RAISE EXCEPTION USING ERRCODE='23514',
      MESSAGE='Partner quote leg scope must exactly match its opportunity';
  END IF;
  IF NEW.shipment_leg_id IS NOT NULL THEN
    SELECT * INTO v_leg FROM public.krim_shipment_legs
    WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id
    FOR KEY SHARE;
    IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE='23514',
        MESSAGE='Partner quote leg must be a plan-linked leg of the same shipment';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_krim_validate_leg_scoped_partner_opportunity
  ON public.krim_partner_opportunities;
CREATE TRIGGER trg_krim_validate_leg_scoped_partner_opportunity
BEFORE INSERT OR UPDATE OF shipment_id, shipment_leg_id
ON public.krim_partner_opportunities
FOR EACH ROW EXECUTE FUNCTION private.krim_validate_leg_scoped_partner_opportunity();

DROP TRIGGER IF EXISTS trg_krim_validate_leg_scoped_partner_quote
  ON public.krim_partner_quotes;
CREATE TRIGGER trg_krim_validate_leg_scoped_partner_quote
BEFORE INSERT OR UPDATE OF shipment_id, shipment_leg_id, opportunity_id
ON public.krim_partner_quotes
FOR EACH ROW EXECUTE FUNCTION private.krim_validate_leg_scoped_partner_quote();

REVOKE ALL ON FUNCTION private.krim_validate_leg_scoped_partner_opportunity() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.krim_validate_leg_scoped_partner_quote() FROM PUBLIC, anon, authenticated;

COMMENT ON COLUMN public.krim_partner_opportunities.shipment_leg_id IS
  'Optional exact leg scope. NULL is legacy shipment-wide only; active multi-leg sourcing must use a plan-linked leg.';
COMMENT ON COLUMN public.krim_partner_quotes.shipment_leg_id IS
  'Exact leg scope inherited from its opportunity; must match the opportunity scope exactly.';
