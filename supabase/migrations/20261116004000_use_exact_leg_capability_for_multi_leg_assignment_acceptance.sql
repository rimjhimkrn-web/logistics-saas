-- Partner acceptance for a future leg-specific assignment must validate the
-- exact leg's transport mode, countries, regions and shipment weight. Preserve
-- the full-shipment capability check for legacy shipment-wide assignments.
DO $migration$
DECLARE
  v_def text;
  v_old text := $old$  if p_accept and not private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) then
    raise exception using errcode='42501', message='Partner capability no longer covers the shipment route, transport mode or weight';
  end if;$old$;
  v_new text := $new$  if p_accept and exists (
    select 1 from public.krim_shipment_leg_plans p
    where p.shipment_id=v_shipment.id and p.status='active' and p.total_legs>1
  ) then
    if v_assignment.shipment_leg_id is null
       or not private.krim_partner_capability_covers_shipment_leg(
         v_assignment.partner_organization_id,v_assignment.shipment_leg_id
       ) then
      raise exception using errcode='42501',
        message='A multi-leg assignment requires verified capability for its exact shipment leg';
    end if;
  elsif p_accept and not private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) then
    raise exception using errcode='42501', message='Partner capability no longer covers the shipment route, transport mode or weight';
  end if;$new$;
BEGIN
  SELECT pg_catalog.pg_get_functiondef(
    'public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure
  ) INTO v_def;
  IF pg_catalog.strpos(v_def,v_old)=0 THEN
    RAISE EXCEPTION 'Expected partner acceptance capability guard not found';
  END IF;
  EXECUTE pg_catalog.replace(v_def,v_old,v_new);
END
$migration$;
