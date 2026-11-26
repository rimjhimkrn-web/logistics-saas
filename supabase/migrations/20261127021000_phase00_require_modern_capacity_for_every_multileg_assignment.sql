-- Phase 00: multi-leg readiness must count only legs with confirmed modern capacity.
DO $migration$
DECLARE
  v_definition text;
  v_expected_md5 constant text := '602b447f01aab06dc30ec42c8294a702';
  v_anchor constant text := E'    join public.krim_partner_shipment_capacity_commitments c\n      on c.assignment_id=a.id\n     and c.partner_organization_id=a.partner_organization_id\n     and c.status=''committed''';
  v_replacement text := E'    join public.krim_partner_shipment_capacity_commitments c\n      on c.assignment_id=a.id\n     and c.partner_organization_id=a.partner_organization_id\n     and c.status=''committed''\n    join public.krim_capacity_leg_bindings b\n      on b.id=a.capacity_binding_id\n     and b.shipment_id=a.shipment_id\n     and b.shipment_leg_id=a.shipment_leg_id\n     and b.status=''confirmed''\n    join public.krim_capacity_reservations r\n      on r.id=b.reservation_id\n     and r.shipment_id=a.shipment_id\n     and r.shipment_leg_id=a.shipment_leg_id\n     and r.organization_id=a.partner_organization_id\n     and r.capacity_availability_id=b.capacity_availability_id\n     and r.status=''confirmed''';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='krim_internal_finalize_partner_assignment'
    AND pg_get_function_identity_arguments(p.oid)='p_assignment_id bigint';

  IF v_definition IS NULL OR md5(v_definition) <> v_expected_md5 THEN
    RAISE EXCEPTION 'Finalization function drift detected; refusing multi-leg patch';
  END IF;

  IF position(v_anchor in v_definition)=0 THEN
    RAISE EXCEPTION 'Expected multi-leg capacity join was not found';
  END IF;

  v_definition := replace(v_definition,v_anchor,v_replacement);

  IF position('join public.krim_capacity_leg_bindings b' in v_definition)=0
     OR position('join public.krim_capacity_reservations r' in v_definition)=0 THEN
    RAISE EXCEPTION 'Multi-leg capacity patch verification failed';
  END IF;

  EXECUTE v_definition;
END
$migration$;
