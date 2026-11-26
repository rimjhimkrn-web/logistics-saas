-- Close the idempotent-replay gap: the original acceptance RPC returned an
-- already-accepted row before rechecking whether its exact partner assignment
-- was still active. Keep the original implementation private-by-ACL and wrap
-- it with a live-link check that runs on every call, including retries.

ALTER FUNCTION public.krim_driver_accept_assignment(uuid)
RENAME TO krim_driver_accept_assignment_unchecked;

REVOKE ALL ON FUNCTION public.krim_driver_accept_assignment_unchecked(uuid)
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.krim_driver_accept_assignment(p_assignment_id uuid)
RETURNS public.krim_driver_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_assignment public.krim_driver_assignments%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='28000', MESSAGE='Authentication required';
  END IF;

  SELECT a.* INTO v_assignment
  FROM public.krim_driver_assignments a
  WHERE a.id=p_assignment_id AND a.user_id=v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='Driver assignment not found for this account';
  END IF;

  IF v_assignment.partner_assignment_id IS NULL
     OR v_assignment.shipment_id IS NULL
     OR v_assignment.shipment_leg_id IS NULL
     OR NOT EXISTS (
       SELECT 1
       FROM public.krim_shipment_partner_assignments pa
       WHERE pa.id=v_assignment.partner_assignment_id
         AND pa.shipment_id=v_assignment.shipment_id
         AND pa.shipment_leg_id=v_assignment.shipment_leg_id
         AND pa.partner_organization_id=v_assignment.organization_id
         AND pa.status IN ('accepted','active')
     ) THEN
    RAISE EXCEPTION USING ERRCODE='55000',
      MESSAGE='The exact linked partner assignment is no longer active; driver acceptance is blocked';
  END IF;

  RETURN public.krim_driver_accept_assignment_unchecked(p_assignment_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_driver_accept_assignment(uuid)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krim_driver_accept_assignment(uuid)
TO authenticated, service_role;
