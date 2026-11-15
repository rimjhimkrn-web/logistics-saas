-- Expire stale partner assignment offers, customer quotes and partner opportunities.
-- This prevents stale awards from holding capacity or appearing as live service offers.
-- Retire the obsolete direct-invitation path: assignments now require a customer-selected partner quote.

CREATE OR REPLACE FUNCTION private.krim_internal_expire_partner_assignment_offers(p_batch_size integer DEFAULT 100)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_assignment record;
  v_opportunity record;
  v_version_id bigint;
  v_version_status text;
  v_count integer := 0;
  v_remaining integer;
BEGIN
  IF p_batch_size IS NULL OR p_batch_size < 1 OR p_batch_size > 500 THEN
    RAISE EXCEPTION USING errcode='22023', message='Batch size must be between 1 and 500';
  END IF;

  v_remaining := p_batch_size;

  -- Expire provider offers that were never accepted, including offers whose
  -- underlying partner quote expired before the response deadline.
  FOR v_assignment IN
    SELECT a.id,a.shipment_id,a.partner_quote_id,a.partner_organization_id,
           a.response_deadline,pq.opportunity_id
    FROM public.krim_shipment_partner_assignments a
    LEFT JOIN public.krim_partner_quotes pq ON pq.id=a.partner_quote_id
    WHERE a.status='offered'
      AND (
        (a.response_deadline IS NOT NULL AND a.response_deadline<=now())
        OR (pq.valid_until IS NOT NULL AND pq.valid_until<=now())
      )
    ORDER BY LEAST(
      COALESCE(a.response_deadline,'infinity'::timestamptz),
      COALESCE(pq.valid_until,'infinity'::timestamptz)
    ),a.id
    FOR UPDATE OF a SKIP LOCKED
    LIMIT v_remaining
  LOOP
    UPDATE public.krim_shipment_partner_assignments
    SET status='rejected',
        rejected_at=now(),
        rejection_reason='Partner response deadline or quote validity expired automatically',
        updated_at=now()
    WHERE id=v_assignment.id AND status='offered';

    IF FOUND THEN
      IF v_assignment.partner_quote_id IS NOT NULL THEN
        UPDATE public.krim_partner_quotes
        SET status='expired',updated_at=now()
        WHERE id=v_assignment.partner_quote_id
          AND status IN ('accepted','submitted','under_review','shortlisted');

        UPDATE public.krim_partner_quotes
        SET status=CASE WHEN valid_until IS NOT NULL AND valid_until<=now() THEN 'expired' ELSE 'submitted' END,
            rejected_at=CASE WHEN valid_until IS NOT NULL AND valid_until<=now() THEN rejected_at ELSE NULL END,
            updated_at=now()
        WHERE opportunity_id=v_assignment.opportunity_id
          AND id<>v_assignment.partner_quote_id
          AND status='rejected';

        UPDATE public.krim_partner_opportunities
        SET status=CASE WHEN response_deadline IS NOT NULL AND response_deadline<=now() THEN 'expired' ELSE 'open' END,
            awarded_partner_organization_id=NULL,
            awarded_at=NULL,
            updated_at=now()
        WHERE id=v_assignment.opportunity_id AND status='awarded';
      END IF;

      INSERT INTO public.krim_audit_events
        (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
      VALUES
        (NULL,v_assignment.partner_organization_id,'partner.assignment.expired','partner_assignment',
         v_assignment.id::text,'automation',
         jsonb_build_object('partner_quote_id',v_assignment.partner_quote_id,'reason','response_deadline_or_quote_expired'),
         jsonb_build_object('status','offered','response_deadline',v_assignment.response_deadline),
         jsonb_build_object('status','rejected','rejection_reason','Partner response deadline or quote validity expired automatically'));

      v_count := v_count + 1;
    END IF;
  END LOOP;

  v_remaining := p_batch_size - v_count;

  -- If the provider accepted but the customer did not accept the quote before
  -- expiry, expire the quote and release the accepted assignment and its
  -- shipment-specific capacity commitment.
  IF v_remaining > 0 THEN
    FOR v_assignment IN
      SELECT a.id,a.shipment_id,a.partner_quote_id,a.partner_organization_id,
             pq.opportunity_id,cq.id AS customer_quote_id,cq.status AS customer_quote_status
      FROM public.krim_shipment_partner_assignments a
      JOIN public.krim_partner_quotes pq ON pq.id=a.partner_quote_id
      JOIN public.krim_quotes cq
        ON cq.partner_quote_id=pq.id
       AND cq.shipment_id=a.shipment_id
      WHERE a.status='accepted'
        AND cq.status IN ('sent','expired')
        AND cq.valid_until IS NOT NULL
        AND cq.valid_until<=now()
      ORDER BY cq.valid_until,a.id
      FOR UPDATE OF a,cq SKIP LOCKED
      LIMIT v_remaining
    LOOP
      IF v_assignment.customer_quote_status='sent' THEN
        UPDATE public.krim_quotes
        SET status='expired',updated_at=now()
        WHERE id=v_assignment.customer_quote_id AND status='sent';
      END IF;

      SELECT qv.id,qv.status
        INTO v_version_id,v_version_status
      FROM public.krim_quote_versions qv
      WHERE qv.quote_id=v_assignment.customer_quote_id
        AND qv.status IN ('sent','accepted')
      ORDER BY qv.version_number DESC
      LIMIT 1
      FOR UPDATE;

      IF v_version_id IS NOT NULL THEN
        UPDATE public.krim_quote_versions
        SET status='expired',superseded_at=now()
        WHERE id=v_version_id;
      END IF;

      IF v_assignment.customer_quote_status='sent' THEN
        INSERT INTO public.krim_quote_events
          (quote_id,version_id,event_type,previous_status,new_status,actor_user_id,event_time,payload)
        VALUES
          (v_assignment.customer_quote_id,v_version_id,'quote.expired_before_customer_acceptance',
           'sent','expired',NULL,now(),
           jsonb_build_object('assignment_id',v_assignment.id,'partner_quote_id',v_assignment.partner_quote_id));
      END IF;

      UPDATE public.krim_shipment_partner_assignments
      SET status='rejected',
          rejected_at=now(),
          rejection_reason='Customer quote expired before final acceptance',
          updated_at=now()
      WHERE id=v_assignment.id AND status='accepted';

      UPDATE public.krim_partner_shipment_capacity_commitments
      SET status='expired',
          updated_at=now(),
          metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object('expiry_reason','customer_quote_expired')
      WHERE assignment_id=v_assignment.id AND status='committed';

      UPDATE public.krim_partner_quotes
      SET status='expired',updated_at=now()
      WHERE id=v_assignment.partner_quote_id AND status='accepted';

      UPDATE public.krim_partner_quotes
      SET status=CASE WHEN valid_until IS NOT NULL AND valid_until<=now() THEN 'expired' ELSE 'submitted' END,
          rejected_at=CASE WHEN valid_until IS NOT NULL AND valid_until<=now() THEN rejected_at ELSE NULL END,
          updated_at=now()
      WHERE opportunity_id=v_assignment.opportunity_id
        AND id<>v_assignment.partner_quote_id
        AND status='rejected';

      UPDATE public.krim_partner_opportunities
      SET status=CASE WHEN response_deadline IS NOT NULL AND response_deadline<=now() THEN 'expired' ELSE 'open' END,
          awarded_partner_organization_id=NULL,
          awarded_at=NULL,
          updated_at=now()
      WHERE id=v_assignment.opportunity_id AND status='awarded';

      INSERT INTO public.krim_audit_events
        (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
      VALUES
        (NULL,v_assignment.partner_organization_id,'partner.assignment.expired','partner_assignment',
         v_assignment.id::text,'automation',
         jsonb_build_object('customer_quote_id',v_assignment.customer_quote_id,'partner_quote_id',v_assignment.partner_quote_id,'reason','customer_quote_expired'),
         jsonb_build_object('status','accepted','customer_quote_status',v_assignment.customer_quote_status),
         jsonb_build_object('status','rejected','capacity_commitment_status','expired'));

      v_count := v_count + 1;
    END LOOP;
  END IF;

  v_remaining := p_batch_size - v_count;

  -- Close stale open opportunities after all outstanding provider offers have
  -- either been accepted or expired. No provider quote is kept artificially live.
  IF v_remaining > 0 THEN
    FOR v_opportunity IN
      SELECT o.id,o.customer_organization_id,o.shipment_id,o.response_deadline
      FROM public.krim_partner_opportunities o
      WHERE o.status='open'
        AND o.response_deadline IS NOT NULL
        AND o.response_deadline<=now()
        AND NOT EXISTS (
          SELECT 1
          FROM public.krim_shipment_partner_assignments a
          WHERE a.shipment_id=o.shipment_id
            AND a.status IN ('offered','accepted','active')
        )
      ORDER BY o.response_deadline,o.id
      FOR UPDATE OF o SKIP LOCKED
      LIMIT v_remaining
    LOOP
      UPDATE public.krim_partner_opportunities
      SET status='expired',updated_at=now()
      WHERE id=v_opportunity.id AND status='open';

      UPDATE public.krim_partner_quotes
      SET status='expired',updated_at=now()
      WHERE opportunity_id=v_opportunity.id
        AND status IN ('submitted','under_review','shortlisted');

      INSERT INTO public.krim_audit_events
        (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
      VALUES
        (NULL,v_opportunity.customer_organization_id,'partner.opportunity.expired','partner_opportunity',
         v_opportunity.id::text,'automation',
         jsonb_build_object('shipment_id',v_opportunity.shipment_id,'response_deadline',v_opportunity.response_deadline),
         jsonb_build_object('status','open'),
         jsonb_build_object('status','expired'));

      v_count := v_count + 1;
    END LOOP;
  END IF;

  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.krim_internal_create_partner_invitations(p_match_run_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION USING errcode='0A000',
    message='Legacy direct partner invitations are retired. Partners must submit verified quotes to open opportunities; customer selection, provider acceptance and customer quote acceptance create the assignment.';
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_internal_create_partner_invitations(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.krim_internal_create_partner_invitations(bigint) TO service_role;
COMMENT ON FUNCTION public.krim_internal_create_partner_invitations(bigint) IS
  'Retired legacy flow. Partner assignments must be created only from customer-selected, verified partner quotes.';

REVOKE ALL ON FUNCTION private.krim_internal_expire_partner_assignment_offers(integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.krim_internal_expire_partner_assignment_offers(integer) TO service_role;

DO $schedule$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname='krim-partner-assignment-expiry';
  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;
  PERFORM cron.schedule(
    'krim-partner-assignment-expiry',
    '*/5 * * * *',
    'SELECT private.krim_internal_expire_partner_assignment_offers(100);'
  );
END;
$schedule$;
