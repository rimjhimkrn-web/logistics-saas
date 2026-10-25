-- Close only stale open partner opportunities that cannot be actioned safely:
-- linked shipment is already closed/cancelled/delivered, or transport mode is missing.
-- Preserve the original row and record the reason in metadata; do not create replacements.

WITH stale AS (
  SELECT o.id
  FROM public.krim_partner_opportunities o
  JOIN public.krim_shipments s ON s.id = o.shipment_id
  WHERE o.status = 'open'
    AND (
      lower(coalesce(s.status, '')) IN ('closed', 'cancelled', 'canceled', 'delivered')
      OR NULLIF(btrim(s.requested_transport_mode), '') IS NULL
    )
)
UPDATE public.krim_partner_opportunities o
SET status = 'cancelled',
    metadata = jsonb_set(
      jsonb_set(
        CASE WHEN jsonb_typeof(o.metadata) = 'object' THEN o.metadata ELSE '{}'::jsonb END,
        '{closure_reason}',
        to_jsonb('shipment_closed_or_missing_transport_mode'::text),
        true
      ),
      '{auto_closed_at}',
      to_jsonb(now()),
      true
    ),
    updated_at = now()
WHERE o.id IN (SELECT id FROM stale)
RETURNING id, shipment_id, status;
