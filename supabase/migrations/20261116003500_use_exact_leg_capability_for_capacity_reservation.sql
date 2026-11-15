-- Capacity reservations are scoped to one shipment leg. Evaluate verified
-- partner capability against that leg's own endpoints and transport mode,
-- not the shipment's legacy single-mode/full-route fields.
DO $migration$
DECLARE
  v_def text;
  v_old text := $old$if not private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) then$old$;
  v_new text := $new$if not private.krim_partner_capability_covers_shipment_leg(v_assignment.partner_organization_id,v_leg.id) then$new$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef(
    'public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure
  ) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN
    RAISE EXCEPTION 'Expected shipment-wide capability guard not found in capacity reservation function';
  END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);
END
$migration$;
