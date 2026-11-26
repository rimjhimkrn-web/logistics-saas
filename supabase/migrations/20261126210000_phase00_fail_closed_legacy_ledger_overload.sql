-- Phase 00: fail closed the obsolete ledger-posting overload.
-- The current ledger schema uses transaction_number, not transaction_reference.
-- The canonical posting path is the overload accepting text source_id and
-- enforcing an open accounting period. This legacy bigint source_id overload
-- has no catalog-tracked dependencies and is not used by the canonical event path.
begin;

create or replace function public.krim_internal_post_ledger_transaction(
  p_organization_id bigint,
  p_transaction_reference text,
  p_transaction_type text,
  p_currency_code text,
  p_debit_account_id bigint,
  p_credit_account_id bigint,
  p_amount numeric,
  p_source_type text default null,
  p_source_id bigint default null,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  raise exception
    'legacy_ledger_posting_overload_disabled: use the transaction_number posting path with text source_id and open accounting period validation'
    using errcode = '0A000';
end;
$function$;

revoke all on function public.krim_internal_post_ledger_transaction(
  bigint,text,text,text,bigint,bigint,numeric,text,bigint,text
) from public, anon, authenticated, service_role;

comment on function public.krim_internal_post_ledger_transaction(
  bigint,text,text,text,bigint,bigint,numeric,text,bigint,text
) is
'Disabled legacy overload. Current ledger schema uses transaction_number; canonical posting path is the text-source_id overload with accounting-period validation.';

commit;
