-- Phase 00 / Checkpoint 16: enforce permission-scoped access to
-- partner capacity reservation details and shipment tracking.
-- Staging-only remediation. Production deployment requires separate approval.

BEGIN;

DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
  v_old_can text;
  v_new_can text;
  v_capacity regprocedure := 'public.krim_partner_list_assignment_capacity_states(bigint[])'::regprocedure;
  v_tracking regprocedure := 'public.krim_get_shipment_tracking(text)'::regprocedure;
BEGIN
  -- Capacity state: active organization membership alone is not sufficient.
  -- Require shipment.assign in the partner organization for every requested
  -- assignment, both in the guard and in the returned-row predicate.
  v_def := pg_get_functiondef(v_capacity);

  v_old := $old$
 IF EXISTS (
  SELECT 1 FROM public.krim_shipment_partner_assignments a
  WHERE a.id=ANY(p_assignment_ids)
   AND NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    WHERE m.organization_id=a.partner_organization_id
     AND m.user_id=v_user_id AND lower(m.status)='active'
   )
 ) THEN
  RAISE EXCEPTION USING errcode='42501',message='One or more assignments are outside your active partner organization membership';
 END IF;
$old$;

  v_new := $new$
 IF EXISTS (
  SELECT 1
  FROM public.krim_shipment_partner_assignments a
  WHERE a.id=ANY(p_assignment_ids)
    AND NOT private.krim_has_permission(v_user_id,a.partner_organization_id,'shipment.assign')
 ) THEN
  RAISE EXCEPTION USING errcode='42501',message='Shipment assignment permission is required for one or more assignments';
 END IF;

 IF EXISTS (
  SELECT 1 FROM public.krim_shipment_partner_assignments a
  WHERE a.id=ANY(p_assignment_ids)
   AND NOT EXISTS (
    SELECT 1 FROM public.krim_organization_members m
    WHERE m.organization_id=a.partner_organization_id
     AND m.user_id=v_user_id AND lower(m.status)='active'
   )
 ) THEN
  RAISE EXCEPTION USING errcode='42501',message='One or more assignments are outside your active partner organization membership';
 END IF;
$new$;

  IF position('private.krim_has_permission(v_user_id,a.partner_organization_id,' || quote_literal('shipment.assign') || ')' in v_def)=0 THEN
    IF position(v_old in v_def)=0 THEN
      RAISE EXCEPTION 'Capacity function source did not match expected safe patch; aborting migration';
    END IF;
    v_def := replace(v_def,v_old,v_new);
    EXECUTE v_def;
  END IF;

  -- Tracking reads require tracking.view. The response may claim that the
  -- caller can record tracking only when tracking.update is granted.
  v_def := pg_get_functiondef(v_tracking);

  v_old := $old$
  SELECT private.krim_has_organization_access(v_uid, v_shipment.customer_organization_id)
    INTO v_allowed
  WHERE v_shipment.customer_organization_id IS NOT NULL;

  IF NOT coalesce(v_allowed, false) THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_organization_members m
        ON m.organization_id = a.partner_organization_id
       AND m.user_id = v_uid
       AND m.status = 'active'
      WHERE a.shipment_id = v_shipment.id
        AND a.status IN ('accepted','active','in_progress','assigned')
    ) INTO v_allowed;
  END IF;

  IF NOT coalesce(v_allowed, false) THEN
    RAISE EXCEPTION 'Shipment not found or access is not permitted';
  END IF;
$old$;

  v_new := $new$
  IF v_shipment.customer_organization_id IS NOT NULL THEN
    v_allowed := private.krim_has_organization_access(v_uid, v_shipment.customer_organization_id)
      AND private.krim_has_permission(v_uid, v_shipment.customer_organization_id, 'tracking.view');
  END IF;

  IF NOT coalesce(v_allowed, false) THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_organization_members m
        ON m.organization_id = a.partner_organization_id
       AND m.user_id = v_uid
       AND m.status = 'active'
      WHERE a.shipment_id = v_shipment.id
        AND a.status IN ('accepted','active','in_progress','assigned')
        AND private.krim_has_permission(v_uid, a.partner_organization_id, 'tracking.view')
    ) INTO v_allowed;
  END IF;

  IF NOT coalesce(v_allowed, false) THEN
    RAISE EXCEPTION 'Shipment not found or access is not permitted';
  END IF;
$new$;

  v_old_can := $oldcan$
    'can_record', EXISTS (
      SELECT 1 FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_organization_members m
        ON m.organization_id = a.partner_organization_id
       AND m.user_id = v_uid AND m.status = 'active'
      WHERE a.shipment_id = v_shipment.id
        AND a.status IN ('accepted','active','in_progress','assigned')
    )
$oldcan$;

  v_new_can := $newcan$
    'can_record', EXISTS (
      SELECT 1 FROM public.krim_shipment_partner_assignments a
      WHERE a.shipment_id = v_shipment.id
        AND a.status IN ('accepted','active','in_progress','assigned')
        AND private.krim_has_permission(v_uid, a.partner_organization_id, 'tracking.update')
    )
$newcan$;

  IF position('private.krim_has_permission(v_uid, v_shipment.customer_organization_id, ' || quote_literal('tracking.view') || ')' in v_def)=0 THEN
    IF position(v_old in v_def)=0 OR position(v_old_can in v_def)=0 THEN
      RAISE EXCEPTION 'Tracking function source did not match expected safe patch; aborting migration';
    END IF;
    v_def := replace(v_def,v_old,v_new);
    v_def := replace(v_def,v_old_can,v_new_can);
    EXECUTE v_def;
  END IF;
END
$migration$;

COMMIT;
