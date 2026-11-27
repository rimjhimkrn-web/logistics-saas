CREATE OR REPLACE FUNCTION krim_internal.release_capacity_on_shipment_terminal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_binding public.krim_capacity_leg_bindings%ROWTYPE;
  v_reservation public.krim_capacity_reservations%ROWTYPE;
  v_org_id bigint;
  v_commitment_status text;
BEGIN
  IF NEW.status NOT IN ('cancelled','completed','delivered','failed')
     OR OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  v_commitment_status := CASE
    WHEN NEW.status='cancelled' THEN 'cancelled'
    WHEN NEW.status='failed' THEN 'expired'
    ELSE 'released'
  END;

  FOR v_binding IN
    SELECT b.*
    FROM public.krim_capacity_leg_bindings b
    WHERE b.shipment_id=NEW.id AND b.status IN ('held','confirmed')
    FOR UPDATE
  LOOP
    v_org_id := NULL;
    v_reservation := NULL;

    IF v_binding.reservation_id IS NOT NULL THEN
      SELECT * INTO v_reservation
      FROM public.krim_capacity_reservations
      WHERE id=v_binding.reservation_id
      FOR UPDATE;

      IF FOUND THEN
        v_org_id := v_reservation.organization_id;
        IF v_reservation.status IN ('held','confirmed') THEN
          UPDATE public.krim_capacity_reservations
          SET status='released', released_at=pg_catalog.now(),
              release_reason='shipment_terminal:'||NEW.status,
              updated_at=pg_catalog.now()
          WHERE id=v_reservation.id;

          INSERT INTO public.krim_capacity_reservation_events
            (reservation_id,event_type,previous_status,new_status,actor_user_id,reason,payload)
          VALUES
            (v_reservation.id,'capacity_released',v_reservation.status,'released',
             auth.uid(),'Shipment entered terminal state: '||NEW.status,
             pg_catalog.jsonb_build_object('shipment_id',NEW.id));
        END IF;
      END IF;
    END IF;

    IF v_org_id IS NULL THEN
      SELECT a.partner_organization_id INTO v_org_id
      FROM public.krim_shipment_partner_assignments a
      WHERE a.capacity_binding_id=v_binding.id
      ORDER BY a.created_at DESC LIMIT 1;
    END IF;

    UPDATE public.krim_capacity_leg_bindings
    SET status='released', released_at=pg_catalog.now(),
        release_reason='shipment_terminal:'||NEW.status,
        updated_at=pg_catalog.now()
    WHERE id=v_binding.id;

    INSERT INTO public.krim_capacity_leg_binding_events
      (binding_id,event_type,previous_status,new_status,actor_user_id,payload)
    VALUES
      (v_binding.id,'capacity_released',v_binding.status,'released',auth.uid(),
       pg_catalog.jsonb_build_object('shipment_id',NEW.id,'terminal_shipment_status',NEW.status));

    INSERT INTO public.krim_audit_events
      (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
    VALUES
      (auth.uid(),v_org_id,'partner.capacity.released','capacity_binding',
       v_binding.id::text,'shipment_lifecycle',
       pg_catalog.jsonb_build_object('shipment_id',NEW.id,'reason','shipment_terminal:'||NEW.status),
       pg_catalog.jsonb_build_object('binding_status',v_binding.status,'reservation_id',v_binding.reservation_id),
       pg_catalog.jsonb_build_object('binding_status','released'));
  END LOOP;

  UPDATE public.krim_partner_shipment_capacity_commitments c
  SET status=v_commitment_status,
      updated_at=pg_catalog.now(),
      metadata=COALESCE(c.metadata,'{}'::jsonb) ||
        pg_catalog.jsonb_build_object(
          'terminal_shipment_status',NEW.status,
          'capacity_released_at',pg_catalog.now(),
          'capacity_release_reason','shipment_terminal:'||NEW.status
        )
  WHERE c.status='committed'
    AND c.assignment_id IN (
      SELECT a.id FROM public.krim_shipment_partner_assignments a
      WHERE a.shipment_id=NEW.id
    );

  UPDATE public.krim_shipment_partner_assignments a
  SET capacity_binding_id=NULL, updated_at=pg_catalog.now()
  WHERE a.shipment_id=NEW.id AND a.capacity_binding_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.krim_capacity_leg_bindings b
      WHERE b.id=a.capacity_binding_id AND b.status='released'
    );

  RETURN NEW;
END;
$function$;