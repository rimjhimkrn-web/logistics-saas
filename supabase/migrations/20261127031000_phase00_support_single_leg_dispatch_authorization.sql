-- Phase 00: allow the modern exact-leg authorization flow for a genuine
-- single-leg shipment while retaining strict active route-plan checks for
-- multi-leg shipments. No legacy shipment-wide bypass is introduced.

CREATE OR REPLACE FUNCTION private.krim_guard_leg_dispatch_authorization()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_plan public.krim_shipment_leg_plans%ROWTYPE;
  v_item public.krim_shipment_leg_plan_items%ROWTYPE;
  v_leg public.krim_shipment_legs%ROWTYPE;
  v_shipment public.krim_shipments%ROWTYPE;
  v_assignment public.krim_shipment_partner_assignments%ROWTYPE;
  v_org public.krim_organizations%ROWTYPE;
  v_mode text;
  v_active_leg_count integer;
BEGIN
  SELECT * INTO v_leg
  FROM public.krim_shipment_legs
  WHERE id=NEW.shipment_leg_id AND shipment_id=NEW.shipment_id
  FOR UPDATE;

  IF NOT FOUND OR v_leg.status <> 'assigned' THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Dispatch authorization requires the exact assigned shipment leg';
  END IF;

  SELECT * INTO v_shipment
  FROM public.krim_shipments
  WHERE id=NEW.shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Dispatch authorization requires an existing shipment';
  END IF;

  SELECT * INTO v_assignment
  FROM public.krim_shipment_partner_assignments
  WHERE id=NEW.partner_assignment_id
    AND shipment_id=NEW.shipment_id
    AND shipment_leg_id=NEW.shipment_leg_id
    AND partner_organization_id=NEW.partner_organization_id
    AND status IN ('accepted','active')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Dispatch authorization requires the accepted exact-leg partner assignment';
  END IF;

  SELECT count(*)::integer INTO v_active_leg_count
  FROM public.krim_shipment_legs
  WHERE shipment_id=NEW.shipment_id AND status <> 'cancelled';

  SELECT p.* INTO v_plan
  FROM public.krim_shipment_leg_plans p
  WHERE p.shipment_id=NEW.shipment_id AND p.status='active'
  ORDER BY p.plan_version DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    IF v_plan.total_legs <= 1 THEN
      RAISE EXCEPTION USING errcode='23514',
        message='An active single-leg route plan is not yet supported; use the canonical unplanned single-leg route or an active multi-leg plan';
    END IF;

    IF v_leg.leg_plan_item_id IS NULL THEN
      RAISE EXCEPTION USING errcode='23514',
        message='Multi-leg dispatch authorization requires a route-plan item linked to the exact leg';
    END IF;

    SELECT i.* INTO v_item
    FROM public.krim_shipment_leg_plan_items i
    WHERE i.id=v_leg.leg_plan_item_id
      AND i.plan_id=v_plan.id
      AND i.leg_sequence=v_leg.leg_sequence
      AND i.origin_location_id=v_leg.origin_location_id
      AND i.destination_location_id=v_leg.destination_location_id
      AND i.transport_mode_id=v_leg.transport_mode_id
      AND i.partner_organization_id=NEW.partner_organization_id
      AND i.assignment_id=NEW.partner_assignment_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING errcode='23514',
        message='Active route-plan item, assigned partner and exact shipment leg do not match';
    END IF;

    IF v_plan.total_legs <> v_active_leg_count THEN
      RAISE EXCEPTION USING errcode='23514',
        message='Active route-plan leg count does not match the active shipment legs';
    END IF;
  ELSE
    IF v_active_leg_count <> 1
       OR v_leg.leg_sequence <> 1
       OR v_leg.leg_plan_item_id IS NOT NULL
       OR v_leg.origin_location_id IS DISTINCT FROM v_shipment.origin_location_id
       OR v_leg.destination_location_id IS DISTINCT FROM v_shipment.destination_location_id THEN
      RAISE EXCEPTION USING errcode='23514',
        message='Single-leg dispatch requires exactly one canonical initial leg matching the shipment route';
    END IF;

    SELECT tm.code INTO v_mode
    FROM public.krim_transport_modes tm
    WHERE tm.id=v_leg.transport_mode_id AND tm.is_active IS TRUE;

    IF v_mode IS NULL OR upper(v_mode) <> upper(coalesce(v_shipment.requested_transport_mode,'')) THEN
      RAISE EXCEPTION USING errcode='23514',
        message='Single-leg transport mode must match the active shipment transport mode';
    END IF;
  END IF;

  SELECT * INTO v_org
  FROM public.krim_organizations
  WHERE id=NEW.partner_organization_id;

  IF NOT FOUND OR v_org.status<>'active'
     OR v_org.partner_account_mode<>'registered_business'
     OR v_org.partner_verification_status NOT IN ('verified','approved')
     OR v_org.partner_lifecycle_status NOT IN ('active','verified')
     OR v_org.partner_compliance_status NOT IN ('clear','compliant','approved','verified','not_required','not_applicable')
     OR private.krim_partner_compliance_is_current(v_org.id) IS NOT TRUE THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Partner must be an active, verified registered business with current compliance';
  END IF;

  IF private.krim_partner_capability_covers_shipment_leg(NEW.partner_organization_id,NEW.shipment_leg_id) IS NOT TRUE THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Current verified partner capability does not cover this exact shipment leg';
  END IF;

  SELECT tm.code INTO v_mode
  FROM public.krim_transport_modes tm
  WHERE tm.id=v_leg.transport_mode_id;

  IF v_mode<>'ROAD' THEN
    RAISE EXCEPTION USING errcode='55000',
      message='Non-road dispatch is held until mode-specific verified resource and execution controls are implemented';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.krim_leg_dispatch_authorization_is_current(
  p_shipment_id bigint,
  p_shipment_leg_id bigint,
  p_partner_assignment_id bigint,
  p_partner_organization_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS(
    SELECT 1
    FROM public.krim_shipment_leg_dispatch_authorizations da
    JOIN public.krim_shipments s ON s.id=da.shipment_id
    JOIN public.krim_shipment_legs l
      ON l.id=da.shipment_leg_id AND l.shipment_id=da.shipment_id
    JOIN public.krim_shipment_partner_assignments pa
      ON pa.id=da.partner_assignment_id
     AND pa.shipment_id=da.shipment_id
     AND pa.shipment_leg_id=da.shipment_leg_id
     AND pa.partner_organization_id=da.partner_organization_id
     AND pa.status IN ('accepted','active')
    JOIN public.krim_organizations o ON o.id=da.partner_organization_id
     AND o.status='active'
     AND o.partner_account_mode='registered_business'
     AND o.partner_verification_status IN ('verified','approved')
     AND o.partner_lifecycle_status IN ('active','verified')
     AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    JOIN public.krim_capacity_leg_bindings cb
      ON cb.id=da.capacity_binding_id
     AND cb.shipment_id=da.shipment_id
     AND cb.shipment_leg_id=da.shipment_leg_id
     AND cb.status='confirmed'
    JOIN public.krim_capacity_reservations cr
      ON cr.id=da.reservation_id
     AND cr.id=cb.reservation_id
     AND cr.shipment_id=da.shipment_id
     AND cr.shipment_leg_id=da.shipment_leg_id
     AND cr.organization_id=da.partner_organization_id
     AND cr.status='confirmed'
    JOIN public.krim_transport_modes tm ON tm.id=l.transport_mode_id
    WHERE da.shipment_id=p_shipment_id
      AND da.shipment_leg_id=p_shipment_leg_id
      AND da.partner_assignment_id=p_partner_assignment_id
      AND da.partner_organization_id=p_partner_organization_id
      AND da.status='authorized'
      AND l.status IN ('assigned','in_transit','completed','delivered')
      AND private.krim_partner_compliance_is_current(o.id) IS TRUE
      AND private.krim_partner_capability_covers_shipment_leg(o.id,l.id) IS TRUE
      AND private.krim_dispatch_handover_is_current(da.shipment_id,da.shipment_leg_id,da.partner_organization_id) IS TRUE
      AND (
        EXISTS(
          SELECT 1
          FROM public.krim_shipment_leg_plans p
          JOIN public.krim_shipment_leg_plan_items i
            ON i.plan_id=p.id
           AND i.id=l.leg_plan_item_id
           AND i.leg_sequence=l.leg_sequence
           AND i.origin_location_id=l.origin_location_id
           AND i.destination_location_id=l.destination_location_id
           AND i.transport_mode_id=l.transport_mode_id
           AND i.partner_organization_id=da.partner_organization_id
           AND i.assignment_id=da.partner_assignment_id
          WHERE p.shipment_id=da.shipment_id
            AND p.status='active'
            AND p.total_legs>1
            AND p.total_legs=(
              SELECT count(*)::integer
              FROM public.krim_shipment_legs active_leg
              WHERE active_leg.shipment_id=da.shipment_id
                AND active_leg.status<>'cancelled'
            )
        )
        OR (
          NOT EXISTS(
            SELECT 1 FROM public.krim_shipment_leg_plans p
            WHERE p.shipment_id=da.shipment_id AND p.status='active'
          )
          AND l.leg_sequence=1
          AND l.leg_plan_item_id IS NULL
          AND l.status IN ('assigned','in_transit','completed','delivered')
          AND (
            SELECT count(*)::integer
            FROM public.krim_shipment_legs active_leg
            WHERE active_leg.shipment_id=da.shipment_id
              AND active_leg.status<>'cancelled'
          )=1
          AND l.origin_location_id=s.origin_location_id
          AND l.destination_location_id=s.destination_location_id
          AND upper(tm.code)=upper(coalesce(s.requested_transport_mode,''))
        )
      )
      AND (
        l.leg_sequence=1
        OR EXISTS(
          SELECT 1
          FROM public.krim_shipment_leg_custody_transfers ct
          JOIN public.krim_shipment_legs prev ON prev.id=ct.from_leg_id
          WHERE ct.shipment_id=l.shipment_id
            AND ct.to_leg_id=l.id
            AND ct.status='accepted'
            AND prev.leg_sequence=l.leg_sequence-1
            AND ct.receiving_organization_id=da.partner_organization_id
        )
      )
  );
$function$;
