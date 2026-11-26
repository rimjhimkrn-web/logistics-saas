begin;

create or replace function krim_internal.create_finance_reconciliation(
 p_organization_id bigint,
 p_period_start timestamptz,
 p_period_end timestamptz,
 p_currency_code text,
 p_source_system text
) returns bigint
language plpgsql security definer
set search_path=pg_catalog,public
as $function$
begin
 raise exception 'legacy_reconciliation_disabled: payment source matching and KRIM-owned commercial revenue reconciliation must be implemented before use'
 using errcode='0A000';
end;
$function$;

create or replace function public.krim_internal_run_financial_reconciliation()
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public
as $function$
begin
 raise exception 'legacy_reconciliation_disabled: legacy payment and partner payout matching is not approved for KRIM current marketplace model'
 using errcode='0A000';
end;
$function$;

create or replace function public.krim_internal_run_financial_reconciliation(p_organization_id bigint)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public
as $function$
begin
 raise exception 'legacy_reconciliation_disabled: legacy payment and partner payout matching is not approved for KRIM current marketplace model'
 using errcode='0A000';
end;
$function$;

create or replace function public.krim_internal_reconcile_customer_receivable(p_payment_id bigint)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public
as $function$
begin
 raise exception 'legacy_receivable_reconciliation_disabled: KRIM must not reconcile partner freight collections as its own receivable'
 using errcode='0A000';
end;
$function$;

create or replace function public.krim_internal_reconcile_partner_payout(p_payable_id bigint)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public
as $function$
begin
 raise exception 'partner_payout_reconciliation_disabled: KRIM partner freight settlement is outside the approved current operating model'
 using errcode='0A000';
end;
$function$;

revoke all on function krim_internal.create_finance_reconciliation(bigint,timestamptz,timestamptz,text,text) from public,anon,authenticated,service_role;
revoke all on function public.krim_internal_run_financial_reconciliation() from public,anon,authenticated,service_role;
revoke all on function public.krim_internal_run_financial_reconciliation(bigint) from public,anon,authenticated,service_role;
revoke all on function public.krim_internal_reconcile_customer_receivable(bigint) from public,anon,authenticated,service_role;
revoke all on function public.krim_internal_reconcile_partner_payout(bigint) from public,anon,authenticated,service_role;

comment on function krim_internal.create_finance_reconciliation(bigint,timestamptz,timestamptz,text,text) is 'Disabled legacy aggregate reconciliation; replace with source-bound KRIM commercial reconciliation.';
comment on function public.krim_internal_run_financial_reconciliation() is 'Disabled legacy payment and partner payout reconciliation; not approved for KRIM current model.';
comment on function public.krim_internal_run_financial_reconciliation(bigint) is 'Disabled legacy payment and partner payout reconciliation; not approved for KRIM current model.';
comment on function public.krim_internal_reconcile_customer_receivable(bigint) is 'Disabled legacy freight receivable reconciliation; KRIM does not own partner freight receivables.';
comment on function public.krim_internal_reconcile_partner_payout(bigint) is 'Disabled legacy partner payout reconciliation; KRIM does not settle partner freight funds.';

commit;