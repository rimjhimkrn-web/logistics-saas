ALTER TABLE public.krim_quotes ADD COLUMN IF NOT EXISTS pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.krim_quotes DROP CONSTRAINT IF EXISTS krim_quotes_pricing_snapshot_object;
ALTER TABLE public.krim_quotes ADD CONSTRAINT krim_quotes_pricing_snapshot_object CHECK (jsonb_typeof(pricing_snapshot)='object');