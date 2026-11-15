CREATE OR REPLACE FUNCTION private.krim_guard_leg_sourcing_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_leg public.krim_shipment_legs%rowtype;
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
BEGIN
  IF TG_TABLE_NAME='krim_partner_opportunities' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status<>'open' THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
  ELSIF TG_TABLE_NAME='krim_partner_quotes' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status NOT IN ('submitted','under_review','shortlisted') THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
  ELSIF TG_TABLE_NAME='krim_shipment_partner_assignments' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status<>'offered' THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Partner assignment must reference a leg belonging to the same shipment'; END IF;
    SELECT * INTO v_quote FROM public.krim_partner_quotes WHERE id=NEW.partner_quote_id FOR KEY SHARE;
    IF NOT FOUND OR v_quote.shipment_id<>NEW.shipment_id OR v_quote.shipment_leg_id IS DISTINCT FROM NEW.shipment_leg_id
       OR v_quote.partner_organization_id<>NEW.partner_organization_id OR v_quote.status<>'accepted' THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Offered assignment must match its accepted quote, partner, shipment and exact leg';
    END IF;
    SELECT * INTO v_opportunity FROM public.krim_partner_opportunities WHERE id=v_quote.opportunity_id FOR KEY SHARE;
    IF NOT FOUND OR v_opportunity.shipment_id<>NEW.shipment_id OR v_opportunity.shipment_leg_id IS DISTINCT FROM NEW.shipment_leg_id
       OR v_opportunity.status<>'awarded' OR v_opportunity.awarded_partner_organization_id IS DISTINCT FROM NEW.partner_organization_id THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Offered assignment must match the awarded opportunity for the same exact leg and partner';
    END IF;
  ELSE RETURN NEW;
  END IF;
  IF NOT FOUND OR v_leg.leg_plan_item_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Leg-scoped sourcing requires a plan-linked leg of the same shipment';
  END IF;
  IF v_leg.status NOT IN ('planned','unassigned') OR v_leg.assignment_status NOT IN ('unassigned','planned','pending') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg is not in an unassigned planned state';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
    WHERE p.shipment_id=NEW.shipment_id AND p.status='active' AND pi.id=v_leg.leg_plan_item_id
      AND pi.leg_sequence=v_leg.leg_sequence AND pi.origin_location_id IS NOT DISTINCT FROM v_leg.origin_location_id
      AND pi.destination_location_id IS NOT DISTINCT FROM v_leg.destination_location_id
      AND pi.transport_mode_id IS NOT DISTINCT FROM v_leg.transport_mode_id
  ) THEN RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Leg no longer matches an item in the active route plan'; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.krim_guard_leg_sourcing_state() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_krim_guard_leg_opportunity_state ON public.krim_partner_opportunities;
CREATE TRIGGER trg_krim_guard_leg_opportunity_state BEFORE INSERT OR UPDATE OF shipment_id,shipment_leg_id,status
ON public.krim_partner_opportunities FOR EACH ROW EXECUTE FUNCTION private.krim_guard_leg_sourcing_state();
DROP TRIGGER IF EXISTS trg_krim_guard_leg_quote_state ON public.krim_partner_quotes;
CREATE TRIGGER trg_krim_guard_leg_quote_state BEFORE INSERT OR UPDATE OF shipment_id,shipment_leg_id,status
ON public.krim_partner_quotes FOR EACH ROW EXECUTE FUNCTION private.krim_guard_leg_sourcing_state();
DROP TRIGGER IF EXISTS trg_krim_guard_leg_assignment_state ON public.krim_shipment_partner_assignments;
CREATE TRIGGER trg_krim_guard_leg_assignment_state BEFORE INSERT OR UPDATE OF shipment_id,shipment_leg_id,partner_organization_id,partner_quote_id,status
ON public.krim_shipment_partner_assignments FOR EACH ROW EXECUTE FUNCTION private.krim_guard_leg_sourcing_state();
