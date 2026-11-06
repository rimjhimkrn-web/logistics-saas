-- Finance mutations must pass through audited SECURITY DEFINER workflows or trusted Edge Functions.
-- The finance workspace is read-only; no browser client may edit orders, chart-of-account rows,
-- or reconciliation findings directly.
revoke insert, update, delete, truncate, references, trigger on table public.payment_orders from public, anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.krim_ledger_accounts from public, anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.krim_financial_reconciliation_exceptions from public, anon, authenticated;
grant select on table public.payment_orders to authenticated;
grant select on table public.krim_ledger_accounts to authenticated;
grant select on table public.krim_financial_reconciliation_exceptions to authenticated;
