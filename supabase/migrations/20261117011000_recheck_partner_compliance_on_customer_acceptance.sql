-- Customer acceptance must revalidate the selected provider's latest compliance review.
-- Status columns alone can remain stale after a review expires or is revoked.
DO $migration$
DECLARE
  v_definition text;
  v_old text := 'AND private.krim_partner_capability_covers_shipment(o.id, v_shipment.id)';
  v_new text := 'AND private.krim_partner_capability_covers_shipment(o.id, v_shipment.id)
      AND private.krim_partner_compliance_is_current(o.id)';
BEGIN
  v_definition := pg_get_functiondef('public.krim_accept_global_quote(bigint)'::regprocedure);
  IF position(v_old in v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected partner capability guard not found in krim_accept_global_quote';
  END IF;
  IF position('private.krim_partner_compliance_is_current(o.id)' in v_definition) > 0 THEN
    RAISE NOTICE 'Current compliance guard already present; no change needed';
  ELSE
    v_definition := replace(v_definition, v_old, v_new);
    EXECUTE v_definition;
  END IF;
END
$migration$;
