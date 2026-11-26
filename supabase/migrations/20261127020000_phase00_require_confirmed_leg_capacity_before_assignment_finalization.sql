-- Phase 00: require the modern confirmed reservation/binding before assignment finalization.
-- Staging-only migration. Preserves existing finalization logic and fails if its source has drifted.
DO $migration$
DECLARE
  v_definition text;
  v_expected_md5 constant text := '1fd37e1164fcd2fbdafdc95449d00199';
  v_declaration_anchor constant text := '  v_commitment public.krim_partner_shipment_capacity_commitments%rowtype;';
  v_validation_anchor constant text := E'  if v_shipment.status=''assigned'' and v_assignment.status in (''active'',''completed'') then';
  v_validation text := $validation$
  -- A modern confirmed physical-capacity reservation is mandatory for every leg.
  -- Lock all three rows so release/expiry cannot race finalization.
  if v_assignment.capacity_binding_id is null then
    raise exception 'Assignment % has no capacity binding', v_assignment.id;
  end if;

  select * into v_binding
  from public.krim_capacity_leg_bindings
  where id = v_assignment.capacity_binding_id
  for update;
  if not found then
    raise exception 'Assignment % references a missing capacity binding', v_assignment.id;
  end if;

  if v_binding.status <> 'confirmed'
     or v_binding.reservation_id is null
     or v_binding.shipment_id <> v_assignment.shipment_id
     or v_binding.shipment_leg_id <> v_assignment.shipment_leg_id then
    raise exception 'Assignment % capacity binding is not confirmed or does not match its shipment leg', v_assignment.id;
  end if;

  select * into v_reservation
  from public.krim_capacity_reservations
  where id = v_binding.reservation_id
  for update;
  if not found then
    raise exception 'Capacity binding % has no linked reservation', v_binding.id;
  end if;

  if v_reservation.status <> 'confirmed'
     or v_reservation.shipment_id is distinct from v_assignment.shipment_id
     or v_reservation.shipment_leg_id is distinct from v_assignment.shipment_leg_id
     or v_reservation.organization_id <> v_assignment.partner_organization_id
     or v_reservation.capacity_availability_id is distinct from v_binding.capacity_availability_id
     or v_reservation.requested_capacity <= 0
     or lower(v_reservation.capacity_unit) <> lower(coalesce(v_binding.capacity_unit, '')) then
    raise exception 'Capacity reservation % is not confirmed or does not match assignment %, shipment leg and partner', v_reservation.id, v_assignment.id;
  end if;

  if not exists (
    select 1
    from public.krim_shipment_legs l
    where l.id = v_assignment.shipment_leg_id
      and l.shipment_id = v_assignment.shipment_id
      and l.partner_organization_id = v_assignment.partner_organization_id
  ) then
    raise exception 'Assignment % shipment leg does not belong to its shipment and partner', v_assignment.id;
  end if;

$validation$;
BEGIN
  SELECT pg_get_functiondef(p.oid)
    INTO v_definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'krim_internal_finalize_partner_assignment'
    AND pg_get_function_identity_arguments(p.oid) = 'p_assignment_id bigint';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'Expected finalization function was not found';
  END IF;

  IF md5(v_definition) <> v_expected_md5 THEN
    RAISE EXCEPTION 'Finalization function drift detected; refusing automatic patch';
  END IF;

  IF position(v_declaration_anchor in v_definition) = 0
     OR position(v_validation_anchor in v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected finalization source anchors were not found';
  END IF;

  v_definition := replace(
    v_definition,
    v_declaration_anchor,
    v_declaration_anchor || E'\n  v_binding public.krim_capacity_leg_bindings%rowtype;\n  v_reservation public.krim_capacity_reservations%rowtype;'
  );

  v_definition := replace(
    v_definition,
    v_validation_anchor,
    v_validation || v_validation_anchor
  );

  IF position('v_binding public.krim_capacity_leg_bindings%rowtype' in v_definition) = 0
     OR position('A modern confirmed physical-capacity reservation is mandatory' in v_definition) = 0 THEN
    RAISE EXCEPTION 'Finalization patch verification failed';
  END IF;

  EXECUTE v_definition;
END
$migration$;

-- Preserve the deployed function's ACL and security-definer attributes through CREATE OR REPLACE.
