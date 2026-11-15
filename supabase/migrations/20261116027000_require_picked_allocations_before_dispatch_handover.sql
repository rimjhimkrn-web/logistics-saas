-- Require picked shipment inventory before warehouse dispatch handover can be created or completed.
CREATE OR REPLACE FUNCTION private.krim_guard_dispatch_handover_picked_allocations()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.task_type = 'dispatch_handover'
     AND (
       TG_OP = 'INSERT'
       OR (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
     ) THEN
    IF NEW.shipment_id IS NULL OR NEW.shipment_leg_id IS NULL THEN
      RAISE EXCEPTION 'Dispatch handover must be linked to an exact shipment leg'
        USING errcode = '23514';
    END IF;

    -- The reservation RPC locks this shipment row before inserting reservations.
    -- Serialising here prevents a new reservation racing with handover creation/completion.
    PERFORM 1
    FROM public.krim_shipments s
    WHERE s.id = NEW.shipment_id
    FOR UPDATE;

    -- Lock all existing allocations while evaluating the final picked state.
    PERFORM 1
    FROM public.krim_warehouse_shipment_allocations a
    WHERE a.organization_id = NEW.organization_id
      AND a.facility_id = NEW.facility_id
      AND a.shipment_id = NEW.shipment_id
      AND a.shipment_leg_id = NEW.shipment_leg_id
    FOR UPDATE;

    IF NOT EXISTS (
      SELECT 1
      FROM public.krim_warehouse_shipment_allocations a
      WHERE a.organization_id = NEW.organization_id
        AND a.facility_id = NEW.facility_id
        AND a.shipment_id = NEW.shipment_id
        AND a.shipment_leg_id = NEW.shipment_leg_id
        AND a.status = 'picked'
    ) THEN
      RAISE EXCEPTION 'Dispatch handover requires at least one picked inventory allocation for this exact shipment leg and facility'
        USING errcode = '23514';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.krim_warehouse_shipment_allocations a
      WHERE a.organization_id = NEW.organization_id
        AND a.facility_id = NEW.facility_id
        AND a.shipment_id = NEW.shipment_id
        AND a.shipment_leg_id = NEW.shipment_leg_id
        AND a.status = 'reserved'
    ) THEN
      RAISE EXCEPTION 'Dispatch handover is blocked while any inventory allocation for this shipment leg remains reserved and unpicked'
        USING errcode = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_guard_dispatch_handover_picked_allocations() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_krim_dispatch_handover_requires_picked_allocations
ON public.krim_warehouse_tasks;

CREATE TRIGGER trg_krim_dispatch_handover_requires_picked_allocations
BEFORE INSERT OR UPDATE OF status
ON public.krim_warehouse_tasks
FOR EACH ROW
EXECUTE FUNCTION private.krim_guard_dispatch_handover_picked_allocations();


-- Make the allocation ledger the authoritative shipment-linked pick record.
-- A separate legacy picking task is no longer required to create handover; the
-- trigger above requires picked stock and rejects outstanding reservations.
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_handover_task(
 p_organization_id bigint,
 p_facility_id uuid,
 p_shipment_id bigint,
 p_shipment_leg_id bigint,
 p_reference_code text,
 p_notes text,
 p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_user uuid := auth.uid();
 v_task public.krim_warehouse_tasks%rowtype;
BEGIN
 IF v_user IS NULL THEN
  RAISE EXCEPTION 'Authentication required' USING errcode='28000';
 END IF;
 IF NOT private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) THEN
  RAISE EXCEPTION 'Verified warehouse facility access and partner.manage permission required' USING errcode='42501';
 END IF;
 IF p_shipment_id IS NULL OR p_shipment_leg_id IS NULL OR p_idempotency_key IS NULL
  OR nullif(btrim(p_reference_code),'') IS NULL OR length(btrim(p_reference_code))>120 THEN
  RAISE EXCEPTION 'Shipment, leg, outbound reference and idempotency key are required' USING errcode='22023';
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.krim_shipment_legs l
  WHERE l.id=p_shipment_leg_id
   AND l.shipment_id=p_shipment_id
   AND l.partner_organization_id=p_organization_id
   AND l.status IN ('assigned','planned','in_transit','arrived')
 ) THEN
  RAISE EXCEPTION 'Shipment leg is not assigned to this warehouse organisation or is not operational' USING errcode='42501';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('krim_wh_task:'||p_organization_id::text||':'||p_idempotency_key::text,0));
 SELECT * INTO v_task
 FROM public.krim_warehouse_tasks
 WHERE organization_id=p_organization_id AND idempotency_key=p_idempotency_key;
 IF FOUND THEN
  IF v_task.facility_id<>p_facility_id
   OR v_task.task_type<>'dispatch_handover'
   OR v_task.reference_code<>btrim(p_reference_code)
   OR v_task.shipment_id<>p_shipment_id
   OR v_task.shipment_leg_id<>p_shipment_leg_id
   OR v_task.notes<>left(coalesce(p_notes,''),4000) THEN
   RAISE EXCEPTION 'Idempotency key was already used for a different handover task' USING errcode='23505';
  END IF;
  RETURN jsonb_build_object('replayed',true,'task',to_jsonb(v_task));
 END IF;
 INSERT INTO public.krim_warehouse_tasks(
  organization_id,facility_id,task_type,reference_code,quality_status,severity,
  notes,idempotency_key,created_by,shipment_id,shipment_leg_id
 )
 VALUES(
  p_organization_id,p_facility_id,'dispatch_handover',btrim(p_reference_code),'pending','normal',
  left(coalesce(p_notes,''),4000),p_idempotency_key,v_user,p_shipment_id,p_shipment_leg_id
 )
 RETURNING * INTO v_task;
 INSERT INTO public.krim_warehouse_task_events(
  task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id
 )
 VALUES(
  v_task.id,p_organization_id,p_facility_id,'task.created','open',
  jsonb_build_object('task_type','dispatch_handover','shipment_id',p_shipment_id,'shipment_leg_id',p_shipment_leg_id),v_user
 );
 RETURN jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
END;
$function$;
REVOKE ALL ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) TO authenticated;
