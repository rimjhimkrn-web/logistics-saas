CREATE OR REPLACE FUNCTION krim_internal.release_capacity_on_assignment_terminal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_binding public.krim_capacity_leg_bindings%ROWTYPE;
  v_reservation public.krim_capacity_reservations%ROWTYPE;
  v_commitment_status text;
BEGIN
  IF NEW.status NOT IN ('rejected','cancelled','completed','failed')
     OR OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  v_commitment_status := CASE
    WHEN NEW.status IN ('rejected','cancelled') THEN 'cancelled'
    WHEN NEW.status = 'failed' THEN 'expired'
    ELSE 'released'
  END;

  -- Release legacy shipment-weight commitment even when no newer binding exists.
  UPDATE public.krim_partner_shipment_capacity_commitments
  SET status = v_commitment_status,
      updated_at = now(),
      metadata = COALESCE(metadata,'{}'::jsonb)
        || jsonb_build_object('terminal_assignment_status',NEW.status,
                              'capacity_released_at',now())
  WHERE assignment_id = NEW.id AND status = 'committed';

  IF NEW.capacity_binding_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_binding
  FROM public.krim_capacity_leg_bindings
  WHERE id = NEW.capacity_binding_id
  FOR UPDATE;

  IF NOT FOUND OR v_binding.status NOT IN ('held','confirmed') THEN
    RETURN NEW;
  END IF;

  IF v_binding.reservation_id IS NOT NULL THEN
    SELECT * INTO v_reservation
    FROM public.krim_capacity_reservations
    WHERE id = v_binding.reservation_id
    FOR UPDATE;

    IF FOUND AND v_reservation.status IN ('held','confirmed') THEN
      UPDATE public.krim_capacity_reservations
      SET status = 'released', released_at = now(),
          release_reason = 'assignment_terminal:' || NEW.status, updated_at = now()
      WHERE id = v_reservation.id;

      INSERT INTO public.krim_capacity_reservation_events
        (reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
      VALUES
        (v_reservation.id,'capacity_released',v_reservation.status,'released',
         auth.uid(),'Assignment entered terminal state: ' || NEW.status,
         jsonb_build_object('assignment_id',NEW.id));
    END IF;
  END IF;

  UPDATE public.krim_capacity_leg_bindings
  SET status = 'released', released_at = now(),
      release_reason = 'assignment_terminal:' || NEW.status, updated_at = now()
  WHERE id = v_binding.id;

  INSERT INTO public.krim_capacity_leg_binding_events
    (binding_id,event_type,previous_status,new_status,actor_user_id,payload)
  VALUES
    (v_binding.id,'capacity_released',v_binding.status,'released',auth.uid(),
     jsonb_build_object('assignment_id',NEW.id,'terminal_assignment_status',NEW.status));

  INSERT INTO public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  VALUES
    (auth.uid(),NEW.partner_organization_id,'partner.capacity.released',
     'capacity_binding',v_binding.id::text,'assignment_lifecycle',
     jsonb_build_object('assignment_id',NEW.id,'reason','assignment_terminal:' || NEW.status),
     jsonb_build_object('binding_status',v_binding.status,'reservation_id',v_binding.reservation_id),
     jsonb_build_object('binding_status','released'));

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION krim_internal.release_capacity_on_assignment_terminal() FROM PUBLIC, anon, authenticated;
