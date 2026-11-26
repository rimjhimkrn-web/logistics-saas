CREATE OR REPLACE FUNCTION public.krim_internal_expire_capacity_holds(p_batch_size integer DEFAULT 200)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_reservation record;
  v_binding record;
  v_count integer := 0;
BEGIN
  IF p_batch_size IS NULL OR p_batch_size < 1 OR p_batch_size > 2000 THEN
    RAISE EXCEPTION USING errcode='22023', message='Batch size must be between 1 and 2000';
  END IF;

  FOR v_reservation IN
    SELECT r.id, r.status
    FROM public.krim_capacity_reservations r
    WHERE r.status='held'
      AND r.hold_expires_at IS NOT NULL
      AND r.hold_expires_at <= pg_catalog.now()
    ORDER BY r.hold_expires_at, r.id
    FOR UPDATE SKIP LOCKED
    LIMIT p_batch_size
  LOOP
    UPDATE public.krim_capacity_reservations
    SET status='expired',
        released_at=pg_catalog.now(),
        release_reason='Capacity hold expired automatically',
        updated_at=pg_catalog.now()
    WHERE id=v_reservation.id AND status='held';

    IF FOUND THEN
      INSERT INTO public.krim_capacity_reservation_events
        (reservation_id,event_type,previous_status,new_status,event_time,actor_user_id,reason,payload)
      VALUES
        (v_reservation.id,'hold_expired',v_reservation.status,'expired',
         pg_catalog.now(),NULL,'Capacity hold expired automatically',
         pg_catalog.jsonb_build_object('source','scheduled_expiry_worker'));

      FOR v_binding IN
        SELECT b.id,b.status
        FROM public.krim_capacity_leg_bindings b
        WHERE b.reservation_id=v_reservation.id
          AND b.status IN ('pending','held')
        FOR UPDATE
      LOOP
        UPDATE public.krim_capacity_leg_bindings
        SET status='expired',
            released_at=pg_catalog.now(),
            release_reason='Linked capacity reservation expired',
            updated_at=pg_catalog.now()
        WHERE id=v_binding.id AND status=v_binding.status;

        IF FOUND THEN
          INSERT INTO public.krim_capacity_leg_binding_events
            (binding_id,event_type,previous_status,new_status,event_time,actor_user_id,payload)
          VALUES
            (v_binding.id,'reservation_expired',v_binding.status,'expired',
             pg_catalog.now(),NULL,
             pg_catalog.jsonb_build_object('reservation_id',v_reservation.id,'source','scheduled_expiry_worker'));

          -- Keep the legacy assignment commitment in lockstep with the modern
          -- reservation. This runs before clearing the assignment's binding FK.
          UPDATE public.krim_partner_shipment_capacity_commitments c
          SET status='expired',
              updated_at=pg_catalog.now(),
              metadata=COALESCE(c.metadata,'{}'::jsonb) ||
                pg_catalog.jsonb_build_object(
                  'capacity_expiry_source','scheduled_expiry_worker',
                  'capacity_reservation_id',v_reservation.id,
                  'capacity_binding_id',v_binding.id,
                  'capacity_expired_at',pg_catalog.now()
                )
          WHERE c.status='committed'
            AND c.assignment_id IN (
              SELECT a.id
              FROM public.krim_shipment_partner_assignments a
              WHERE a.capacity_binding_id=v_binding.id
            );

          UPDATE public.krim_shipment_partner_assignments
          SET capacity_binding_id=NULL,updated_at=pg_catalog.now()
          WHERE capacity_binding_id=v_binding.id;
        END IF;
      END LOOP;
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$function$;

COMMENT ON FUNCTION public.krim_internal_expire_capacity_holds(integer) IS
'Expires held modern capacity reservations and linked bindings; synchronizes any linked committed legacy assignment capacity record to expired before clearing the assignment binding reference.';