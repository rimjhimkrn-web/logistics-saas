-- Phase 00: make hold expiry event-accurate and clear stale assignment links.
DO $migration$
DECLARE
 v_definition text;
 v_expected_md5 constant text := 'eac9e4460cbd3372d4f34f59861be79c';
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO v_definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public'
   AND p.proname='krim_internal_expire_capacity_holds'
   AND pg_get_function_identity_arguments(p.oid)='p_batch_size integer';
 IF v_definition IS NULL OR md5(v_definition)<>v_expected_md5 THEN
   RAISE EXCEPTION 'Capacity expiry function drift detected; refusing replacement';
 END IF;

 EXECUTE $function$
 CREATE OR REPLACE FUNCTION public.krim_internal_expire_capacity_holds(p_batch_size integer DEFAULT 200)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 AS $body$
 DECLARE
   v_reservation record;
   v_binding record;
   v_count integer:=0;
 BEGIN
   IF p_batch_size IS NULL OR p_batch_size<1 OR p_batch_size>2000 THEN
     RAISE EXCEPTION USING errcode='22023',message='Batch size must be between 1 and 2000';
   END IF;

   FOR v_reservation IN
     SELECT r.id,r.status
     FROM public.krim_capacity_reservations r
     WHERE r.status='held'
       AND r.hold_expires_at IS NOT NULL
       AND r.hold_expires_at<=pg_catalog.now()
     ORDER BY r.hold_expires_at,r.id
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
         WHERE id=v_binding.id
           AND status=v_binding.status;

         IF FOUND THEN
           INSERT INTO public.krim_capacity_leg_binding_events
             (binding_id,event_type,previous_status,new_status,event_time,actor_user_id,payload)
           VALUES
             (v_binding.id,'reservation_expired',v_binding.status,'expired',
              pg_catalog.now(),NULL,
              pg_catalog.jsonb_build_object('reservation_id',v_reservation.id,'source','scheduled_expiry_worker'));

           UPDATE public.krim_shipment_partner_assignments
           SET capacity_binding_id=NULL,updated_at=pg_catalog.now()
           WHERE capacity_binding_id=v_binding.id;
         END IF;
       END LOOP;
       v_count:=v_count+1;
     END IF;
   END LOOP;
   RETURN v_count;
 END;
 $body$;
 $function$;
END
$migration$;

REVOKE ALL ON FUNCTION public.krim_internal_expire_capacity_holds(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.krim_internal_expire_capacity_holds(integer) TO service_role;
