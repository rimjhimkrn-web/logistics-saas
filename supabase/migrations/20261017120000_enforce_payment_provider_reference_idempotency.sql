-- Prevent concurrent payment-verification retries from creating duplicate provider transactions.
-- The production database was checked for existing duplicates before this index was added.
CREATE UNIQUE INDEX IF NOT EXISTS uq_krim_financial_transactions_provider_reference
ON public.krim_financial_transactions (provider, provider_reference)
WHERE provider IS NOT NULL AND provider_reference IS NOT NULL;
