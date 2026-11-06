-- Revenue recognition remains suspended until GST is split from taxable service revenue.
-- The current event posting helper uses invoice.total_amount; posting that amount
-- entirely to freight revenue would misstate output GST where GST applies.
update public.krim_accounting_posting_rules
set status='suspended',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'suspension_reason','GST output-tax split and invoice subtotal/tax accounting must be validated before revenue recognition can post',
      'suspended_at',now(),
      'safety_gate','NO_REVENUE_POSTING_UNTIL_TAX_SPLIT_VERIFIED'
    ),
    updated_at=now()
where organization_id=21
  and currency_code='INR'
  and event_type='revenue_recognition'
  and status='active';
