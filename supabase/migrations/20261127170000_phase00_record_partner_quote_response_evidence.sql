-- Phase 00: append immutable partner response evidence to the customer quote event ledger.
-- Partner response is evidence of provider acceptance/rejection, not a KRIM freight contract.

CREATE OR REPLACE FUNCTION private.krim_record_partner_quote_response_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_quote public.krim_quotes%ROWTYPE;
  v_partner_quote public.krim_partner_quotes%ROWTYPE;
  v_version_id bigint;
  v_event_type text;
  v_previous_status text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
      RETURN NEW;
    END IF;
    v_previous_status := OLD.status;
  ELSE
    v_previous_status := NULL;
  END IF;

  IF NEW.status NOT IN ('accepted','rejected') THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_partner_quote
  FROM public.krim_partner_quotes
  WHERE id = NEW.partner_quote_id
    AND shipment_id = NEW.shipment_id
    AND partner_organization_id = NEW.partner_organization_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23503',
      message='Partner response evidence requires the exact matching partner quote';
  END IF;

  SELECT * INTO v_quote
  FROM public.krim_quotes
  WHERE shipment_id = NEW.shipment_id
    AND partner_quote_id = NEW.partner_quote_id
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='23514',
      message='Partner response cannot be recorded without its matching customer quote';
  END IF;

  SELECT id INTO v_version_id
  FROM public.krim_quote_versions
  WHERE quote_id = v_quote.id
  ORDER BY version_number DESC
  LIMIT 1;

  v_event_type := CASE
    WHEN NEW.status = 'accepted' THEN 'partner.quote_accepted'
    ELSE 'partner.quote_rejected'
  END;

  INSERT INTO public.krim_quote_events (
    quote_id, version_id, event_type, previous_status, new_status,
    actor_user_id, event_time, payload
  ) VALUES (
    v_quote.id, v_version_id, v_event_type,
    v_previous_status, NEW.status,
    auth.uid(), clock_timestamp(),
    jsonb_build_object(
      'quote_id', v_quote.id,
      'shipment_id', NEW.shipment_id,
      'customer_organization_id', v_quote.customer_organization_id,
      'partner_quote_id', v_partner_quote.id,
      'partner_quote_number', v_partner_quote.quote_number,
      'partner_organization_id', NEW.partner_organization_id,
      'assignment_id', NEW.id,
      'assignment_number', NEW.assignment_number,
      'assignment_status', NEW.status,
      'assignment_response_deadline', NEW.response_deadline,
      'assignment_accepted_at', NEW.accepted_at,
      'assignment_rejected_at', NEW.rejected_at,
      'capacity_binding_id', NEW.capacity_binding_id,
      'partner_quote_snapshot', to_jsonb(v_partner_quote),
      'partner_response_actor', auth.uid(),
      'response_recorded_at', clock_timestamp(),
      'evidence_scope', 'partner_response_record_not_a_signed_contract'
    )
  );

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.krim_record_partner_quote_response_event()
FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_krim_record_partner_quote_response_event
ON public.krim_shipment_partner_assignments;

CREATE TRIGGER trg_krim_record_partner_quote_response_event
AFTER INSERT OR UPDATE OF status
ON public.krim_shipment_partner_assignments
FOR EACH ROW
EXECUTE FUNCTION private.krim_record_partner_quote_response_event();
