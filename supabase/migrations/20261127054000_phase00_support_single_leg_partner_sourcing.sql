CREATE OR REPLACE FUNCTION private.krim_guard_leg_sourcing_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_leg public.krim_shipment_legs%rowtype;
  v_quote public.krim_partner_quotes%rowtype;
  v_opportunity public.krim_partner_opportunities%rowtype;
  v_shipment public.krim_shipments%rowtype;
BEGIN
  IF TG_TABLE_NAME='krim_partner_opportunities' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status<>'open' THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs
    WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
  ELSIF TG_TABLE_NAME='krim_partner_quotes' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status NOT IN ('submitted','under_review','shortlisted') THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs
    WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
  ELSIF TG_TABLE_NAME='krim_shipment_partner_assignments' THEN
    IF NEW.shipment_leg_id IS NULL OR NEW.status<>'offered' THEN RETURN NEW; END IF;
    SELECT * INTO v_leg FROM public.krim_shipment_legs
    WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id FOR KEY SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Partner assignment must reference a leg belonging to the same shipment';
    END IF;
    SELECT * INTO v_quote FROM public.krim_partner_quotes
    WHERE id=NEW.partner_quote_id FOR KEY SHARE;
    IF NOT FOUND OR v_quote.shipment_id<>NEW.shipment_id
       OR v_quote.shipment_leg_id IS DISTINCT FROM NEW.shipment_leg_id
       OR v_quote.partner_organization_id<>NEW.partner_organization_id
       OR v_quote.status<>'accepted' THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Offered assignment must match its accepted quote, partner, shipment and exact leg';
    END IF;
    SELECT * INTO v_opportunity FROM public.krim_partner_opportunities
    WHERE id=v_quote.opportunity_id FOR KEY SHARE;
    IF NOT FOUND OR v_opportunity.shipment_id<>NEW.shipment_id
       OR v_opportunity.shipment_leg_id IS DISTINCT FROM NEW.shipment_leg_id
       OR v_opportunity.status<>'awarded'
       OR v_opportunity.awarded_partner_organization_id IS DISTINCT FROM NEW.partner_organization_id THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Offered assignment must match the awarded opportunity for the same exact leg and partner';
    END IF;
  ELSE
    RETURN NEW;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Sourcing record must reference a leg belonging to the same shipment';
  END IF;

  IF v_leg.status NOT IN ('planned','unassigned')
     OR v_leg.assignment_status NOT IN ('unassigned','planned','pending') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='Leg is not in an unassigned planned state';
  END IF;

  IF TG_TABLE_NAME='krim_shipment_partner_assignments'
     AND v_leg.leg_plan_item_id IS NULL THEN
    SELECT * INTO v_shipment
    FROM public.krim_shipments
    WHERE id=NEW.shipment_id
    FOR KEY SHARE;

    IF NOT FOUND
       OR EXISTS (
         SELECT 1 FROM public.krim_shipment_legs l
         WHERE l.shipment_id=NEW.shipment_id
           AND l.id<>v_leg.id
           AND l.status<>'cancelled'
       )
       OR v_leg.leg_sequence<>1
       OR v_leg.origin_location_id IS DISTINCT FROM v_shipment.origin_location_id
       OR v_leg.destination_location_id IS DISTINCT FROM v_shipment.destination_location_id
       OR NOT EXISTS (
         SELECT 1
         FROM public.krim_transport_modes tm
         WHERE tm.id=v_leg.transport_mode_id
           AND tm.is_active=true
           AND upper(tm.code)=upper(v_shipment.requested_transport_mode)
       )
       OR EXISTS (
         SELECT 1 FROM public.krim_shipment_leg_plans p
         WHERE p.shipment_id=NEW.shipment_id
           AND p.status='active'
           AND p.total_legs>1
       ) THEN
      RAISE EXCEPTION USING ERRCODE='23514',
        MESSAGE='Unplanned single-leg sourcing requires exactly one canonical leg matching the shipment route and active requested transport mode';
    END IF;
    RETURN NEW;
  END IF;

  IF v_leg.leg_plan_item_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='Leg-scoped sourcing requires a plan-linked leg or a canonical single-leg assignment';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.krim_shipment_leg_plans p
    JOIN public.krim_shipment_leg_plan_items pi ON pi.plan_id=p.id
    WHERE p.shipment_id=NEW.shipment_id AND p.status='active'
      AND pi.id=v_leg.leg_plan_item_id
      AND pi.leg_sequence=v_leg.leg_sequence
      AND pi.origin_location_id IS NOT DISTINCT FROM v_leg.origin_location_id
      AND pi.destination_location_id IS NOT DISTINCT FROM v_leg.destination_location_id
      AND pi.transport_mode_id IS NOT DISTINCT FROM v_leg.transport_mode_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Leg no longer matches an item in the active route plan';
  END IF;

  RETURN NEW;
END;
$function$;
