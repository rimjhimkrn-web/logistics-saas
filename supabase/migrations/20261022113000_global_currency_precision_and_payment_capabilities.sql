-- Global currency precision and capability-gated international payment readiness.
-- Foreign currencies remain disabled until merchant eligibility, presentment,
-- settlement, refunds, FX and end-to-end reconciliation are independently verified.

create or replace function private.krim_currency_minor_unit_exponent(p_currency text)
returns integer
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case upper(trim(coalesce(p_currency,'')))
    when 'BIF' then 0 when 'CLP' then 0 when 'DJF' then 0
    when 'GNF' then 0 when 'ISK' then 0 when 'JPY' then 0
    when 'KMF' then 0 when 'KRW' then 0 when 'PYG' then 0
    when 'RWF' then 0 when 'UGX' then 0 when 'UYI' then 0
    when 'VND' then 0 when 'VUV' then 0 when 'XAF' then 0
    when 'XOF' then 0 when 'XPF' then 0
    when 'BHD' then 3 when 'IQD' then 3 when 'JOD' then 3
    when 'KWD' then 3 when 'LYD' then 3 when 'OMR' then 3
    when 'TND' then 3
    when 'CLF' then 4 when 'UYW' then 4
    else 2
  end;
$$;

do $$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef('public.krim_create_tariff_quote(bigint,text,timestamp with time zone)'::regprocedure);
  if position('round(v_amount,2)' in v_definition) > 0 then
    v_definition := replace(v_definition, 'round(v_amount,2)', 'round(v_amount,private.krim_currency_minor_unit_exponent(v_rate.currency_code))');
    execute v_definition;
  elsif position('round(v_amount,private.krim_currency_minor_unit_exponent(v_rate.currency_code))' in v_definition) = 0 then
    raise exception 'Could not identify the tariff quote amount-rounding expression';
  end if;
end;
$$;

insert into public.krim_payment_capability_registry
(country_code,currency_code,provider_code,integration_status,checkout_enabled,merchant_eligibility_verified,presentment_supported,settlement_supported,refunds_supported,fx_supported,supported_methods,notes)
values
('IN','USD','razorpay','planned',false,false,false,false,false,false,'{}'::text[],'International currency capability reserved for KRIM India merchant context. Disabled until Razorpay activation, currency presentment, settlement, refunds, FX and end-to-end reconciliation are verified.'),
('IN','EUR','razorpay','planned',false,false,false,false,false,false,'{}'::text[],'International currency capability reserved for KRIM India merchant context. Disabled until Razorpay activation, currency presentment, settlement, refunds, FX and end-to-end reconciliation are verified.'),
('IN','GBP','razorpay','planned',false,false,false,false,false,false,'{}'::text[],'International currency capability reserved for KRIM India merchant context. Disabled until Razorpay activation, currency presentment, settlement, refunds, FX and end-to-end reconciliation are verified.'),
('IN','AED','razorpay','planned',false,false,false,false,false,false,'{}'::text[],'International currency capability reserved for KRIM India merchant context. Disabled until Razorpay activation, currency presentment, settlement, refunds, FX and end-to-end reconciliation are verified.'),
('IN','SGD','razorpay','planned',false,false,false,false,false,false,'{}'::text[],'International currency capability reserved for KRIM India merchant context. Disabled until Razorpay activation, currency presentment, settlement, refunds, FX and end-to-end reconciliation are verified.')
on conflict (country_code,currency_code,provider_code) do update
set integration_status = case
  when public.krim_payment_capability_registry.merchant_eligibility_verified
    and public.krim_payment_capability_registry.presentment_supported
    and public.krim_payment_capability_registry.settlement_supported
    and public.krim_payment_capability_registry.refunds_supported
    and public.krim_payment_capability_registry.fx_supported
  then public.krim_payment_capability_registry.integration_status
  else 'planned'
end,
checkout_enabled = case
  when public.krim_payment_capability_registry.merchant_eligibility_verified
    and public.krim_payment_capability_registry.presentment_supported
    and public.krim_payment_capability_registry.settlement_supported
    and public.krim_payment_capability_registry.refunds_supported
    and public.krim_payment_capability_registry.fx_supported
  then public.krim_payment_capability_registry.checkout_enabled
  else false
end,
notes = case
  when public.krim_payment_capability_registry.merchant_eligibility_verified
    and public.krim_payment_capability_registry.presentment_supported
    and public.krim_payment_capability_registry.settlement_supported
    and public.krim_payment_capability_registry.refunds_supported
    and public.krim_payment_capability_registry.fx_supported
  then public.krim_payment_capability_registry.notes
  else excluded.notes
end,
updated_at = now();
