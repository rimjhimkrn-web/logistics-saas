begin;

create or replace function public.krim_guard_immutable_ledger_record()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if tg_op='TRUNCATE' then
    raise exception 'ledger_records_are_immutable: truncation is prohibited' using errcode='55000';
  end if;

  if tg_table_name='krim_ledger_entries' then
    if tg_op='DELETE' then
      raise exception 'ledger_entries_are_immutable: post a reversal instead' using errcode='55000';
    end if;
    if tg_op='UPDATE' then
      raise exception 'ledger_entries_are_immutable: post a reversal instead' using errcode='55000';
    end if;
  elsif tg_table_name='krim_ledger_transactions' then
    if tg_op='DELETE' then
      raise exception 'ledger_transactions_are_immutable: post a reversal instead' using errcode='55000';
    end if;
    if tg_op='UPDATE' and old.status in ('posted','reversed','voided') then
      raise exception 'posted_ledger_transactions_are_immutable: post a reversal instead' using errcode='55000';
    end if;
  end if;

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$;

drop trigger if exists trg_krim_ledger_entries_immutable on public.krim_ledger_entries;
create trigger trg_krim_ledger_entries_immutable
before update or delete on public.krim_ledger_entries
for each row execute function public.krim_guard_immutable_ledger_record();

drop trigger if exists trg_krim_ledger_entries_no_truncate on public.krim_ledger_entries;
create trigger trg_krim_ledger_entries_no_truncate
before truncate on public.krim_ledger_entries
for each statement execute function public.krim_guard_immutable_ledger_record();

drop trigger if exists trg_krim_ledger_transactions_immutable on public.krim_ledger_transactions;
create trigger trg_krim_ledger_transactions_immutable
before update or delete on public.krim_ledger_transactions
for each row execute function public.krim_guard_immutable_ledger_record();

drop trigger if exists trg_krim_ledger_transactions_no_truncate on public.krim_ledger_transactions;
create trigger trg_krim_ledger_transactions_no_truncate
before truncate on public.krim_ledger_transactions
for each statement execute function public.krim_guard_immutable_ledger_record();

revoke update, delete, truncate on public.krim_ledger_entries from service_role;
revoke update, delete, truncate on public.krim_ledger_transactions from service_role;

revoke all on function public.krim_guard_immutable_ledger_record() from public, anon, authenticated, service_role;

comment on function public.krim_guard_immutable_ledger_record() is
'Trigger guard: ledger entries are append-only; posted/reversed/voided transactions cannot be edited or deleted; use compensating reversal postings.';

commit;