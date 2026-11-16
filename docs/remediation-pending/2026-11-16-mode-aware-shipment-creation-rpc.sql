-- KRIM booking creation remediation proposal — NOT A MIGRATION.
-- DO NOT APPLY to production until the migration history is reconciled,
-- this definition is compared with the canonical live catalog, and staging
-- tests plus owner/ACL/search_path review are complete.
--
-- Finding: public.krim_create_global_shipment(bigint,bigint,bigint,text,numeric)
-- inserts a krim_shipments row without requested_transport_mode. The live
-- BEFORE INSERT trigger krim_enforce_corridor_compliance_before_shipment_write
-- rejects that row because it requires requested_transport_mode before insert.
-- The existing from_places(..., p_transport_mode) wrapper calls the legacy
-- five-argument function first and only updates the mode afterwards, so it
-- encounters the same trigger failure.
--
-- This new mode-aware contract inserts requested_transport_mode atomically.
-- The existing corridor/market triggers remain the authoritative route gate.
-- No fallback to the legacy RPC is permitted.

CREATE OR REPLACE FUNCTION public.krim_create_global_shipment_with_mode(
  p_customer_organization_id bigint,
  p_origin_location_id bigint,
  p_destination_location_id bigint,
  p_goods_description text,
  p_total_weight_kg numeric,
  p_transport_mode text
)
RETURNS public.krim_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_shipment public.krim_shipments%ROWTYPE;
  v_origin_country_id bigint;
  v_destination_country_id bigint;
  v_mode text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING errcode='28000',message='Authentication required';
  END IF;
  IF p_customer_organization_id IS NULL
     OR NOT public.krim_has_organization_access(auth.uid(),p_customer_organization_id) THEN
    RAISE EXCEPTION USING errcode='42501',message='Organization access denied';
  END IF;
  IF NOT public.krim_has_permission(auth.uid(),p_customer_organization_id,'shipment.create') THEN
    RAISE EXCEPTION USING errcode='42501',message='Permission denied: shipment.create';
  END IF;
  IF p_origin_location_id IS NULL OR p_destination_location_id IS NULL
     OR p_origin_location_id=p_destination_location_id THEN
    RAISE EXCEPTION USING errcode='22023',message='Choose two different origin and destination locations';
  END IF;
  IF p_goods_description IS NULL OR length(btrim(p_goods_description))=0
     OR length(p_goods_description)>500 THEN
    RAISE EXCEPTION USING errcode='22023',message='Goods description is required and limited to 500 characters';
  END IF;
  IF p_total_weight_kg IS NULL OR p_total_weight_kg<=0
     OR p_total_weight_kg>100000000 THEN
    RAISE EXCEPTION USING errcode='22023',message='Weight must be greater than zero and within the supported range';
  END IF;
  v_mode:=lower(btrim(coalesce(p_transport_mode,'')));
  IF v_mode NOT IN ('road','rail','ocean','air','multimodal','warehouse_transfer','specialist') THEN
    RAISE EXCEPTION USING errcode='22023',message='Choose a supported transport mode';
  END IF;

  SELECT l.country_id INTO v_origin_country_id
  FROM public.krim_locations l
  JOIN public.krim_countries c ON c.id=l.country_id AND c.is_active=true
  WHERE l.id=p_origin_location_id AND l.is_active=true;
  IF v_origin_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023',message='Origin location or country is inactive';
  END IF;

  SELECT l.country_id INTO v_destination_country_id
  FROM public.krim_locations l
  JOIN public.krim_countries c ON c.id=l.country_id AND c.is_active=true
  WHERE l.id=p_destination_location_id AND l.is_active=true;
  IF v_destination_country_id IS NULL THEN
    RAISE EXCEPTION USING errcode='22023',message='Destination location or country is inactive';
  END IF;

  IF NOT private.krim_market_country_operational(v_origin_country_id)
     OR NOT private.krim_market_country_operational(v_destination_country_id) THEN
    RAISE EXCEPTION USING errcode='42501',message='Both endpoint markets must be operationally activated';
  END IF;

  INSERT INTO public.krim_shipments(
    customer_organization_id,origin_location_id,destination_location_id,
    goods_description,total_weight_kg,requested_transport_mode,status
  )
  VALUES(
    p_customer_organization_id,p_origin_location_id,p_destination_location_id,
    btrim(p_goods_description),p_total_weight_kg,v_mode,'draft'
  )
  RETURNING * INTO v_shipment;

  RETURN v_shipment;
END;
$function$;

-- ACL/ownership are intentionally not changed here. Reconcile the live
-- function owner, grants, dependencies and caller roles before deployment.
-- Do not grant EXECUTE to anon. Authenticated execution must be explicitly
-- reviewed against the current permission model.
--
-- Staging-only test matrix:
-- A. Missing auth, wrong tenant, missing shipment.create => denied.
-- B. Null/invalid mode, empty description, invalid weight => rejected.
-- C. Inactive locations/countries or inactive market controls => rejected.
-- D. Active endpoint markets but missing exact approved corridor dossier,
--    mode match or mandatory current controls => rejected by existing trigger.
-- E. Fully approved staging corridor and valid shipment => row inserted with
--    requested_transport_mode already populated; initial leg trigger runs.
-- F. Verify rollback leaves no shipment/leg/opportunity on every failure.
-- G. Verify function owner, ACL, SECURITY DEFINER search_path, trigger order,
--    audit events and downstream readiness before any release.
