-- Harden canonical ledger posting: scoped lock, payload-safe replay, balanced-entry verification.
begin;

create or replace function public.krim_internal_post_ledger_transaction(
  p_organization_id bigint,
  p_transaction_number text,
  p_transaction_type text,
  p_currency_code text,
  p_debit_account_id bigint,
  p_credit_account_id bigint,
  p_amount numeric,
  p_description text default null,
  p_source_type text default null,
  p_source_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_tx public.krim_ledger_transactions%rowtype;
  v_debit public.krim_ledger_accounts%rowtype;
  v_credit public.krim_ledger_accounts%rowtype;
  v_period public.krim_accounting_periods%rowtype;
  v_debit_count integer;
  v_credit_count integer;
  v_debit_total numeric;
  v_credit_total numeric;
begin
  if p_organization_id is null or p_organization_id <= 0 then
    raise exception 'ledger_organization_required' using errcode='22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'ledger_amount_must_be_positive' using errcode='22023';
  end if;
  if p_debit_account_id is null or p_credit_account_id is null
     or p_debit_account_id = p_credit_account_id then
    raise exception 'ledger_distinct_accounts_required' using errcode='22023';
  end if;
  if nullif(btrim(p_transaction_number),'') is null then
    raise exception 'transaction_number_required' using errcode='22023';
  end if;
  if nullif(btrim(p_transaction_type),'') is null
     or nullif(btrim(p_currency_code),'') is null then
    raise exception 'ledger_type_and_currency_required' using errcode='22023';
  end if;

  -- Serialize identical idempotency keys, including concurrent first attempts.
  perform pg_advisory_xact_lock(
    hashtextextended(p_organization_id::text || ':' || btrim(p_transaction_number), 0)
  );

  select * into v_tx
  from public.krim_ledger_transactions
  where transaction_number=btrim(p_transaction_number)
  for update;

  if found then
    if v_tx.organization_id <> p_organization_id
       or v_tx.transaction_type <> p_transaction_type
       or upper(v_tx.currency_code) <> upper(p_currency_code)
       or v_tx.source_type is distinct from p_source_type
       or v_tx.source_id is distinct from p_source_id
       or v_tx.status <> 'posted' then
      raise exception 'ledger_idempotency_conflict: transaction number already belongs to a different posting'
        using errcode='23505';
    end if;

    select count(*) filter(where entry_type='debit'),
           count(*) filter(where entry_type='credit'),
           coalesce(sum(amount) filter(where entry_type='debit'),0),
           coalesce(sum(amount) filter(where entry_type='credit'),0)
      into v_debit_count,v_credit_count,v_debit_total,v_credit_total
    from public.krim_ledger_entries
    where transaction_id=v_tx.id;

    if v_debit_count <> 1 or v_credit_count <> 1
       or v_debit_total <> p_amount or v_credit_total <> p_amount
       or v_debit_total <> v_credit_total
       or not exists(select 1 from public.krim_ledger_entries
                     where transaction_id=v_tx.id and entry_type='debit'
                       and account_id=p_debit_account_id)
       or not exists(select 1 from public.krim_ledger_entries
                     where transaction_id=v_tx.id and entry_type='credit'
                       and account_id=p_credit_account_id) then
      raise exception 'ledger_idempotency_conflict: existing posting does not match requested balanced entries'
        using errcode='23505';
    end if;

    return jsonb_build_object(
      'ok',true,'idempotent',true,'transaction_id',v_tx.id,
      'transaction_number',v_tx.transaction_number,'status',v_tx.status,
      'balanced',true
    );
  end if;

  select * into v_debit
  from public.krim_ledger_accounts
  where id=p_debit_account_id and organization_id=p_organization_id and status='active'
  for update;
  if not found then raise exception 'debit_account_invalid'; end if;

  select * into v_credit
  from public.krim_ledger_accounts
  where id=p_credit_account_id and organization_id=p_organization_id and status='active'
  for update;
  if not found then raise exception 'credit_account_invalid'; end if;

  if upper(v_debit.currency_code) <> upper(p_currency_code)
     or upper(v_credit.currency_code) <> upper(p_currency_code) then
    raise exception 'ledger_currency_mismatch';
  end if;

  select * into v_period
  from public.krim_accounting_periods
  where organization_id=p_organization_id
    and current_date between period_start and period_end
  order by period_start desc
  limit 1
  for update;

  if not found then raise exception 'open_accounting_period_missing'; end if;
  if v_period.status <> 'open' then raise exception 'accounting_period_not_open'; end if;

  insert into public.krim_ledger_transactions(
    organization_id,transaction_number,transaction_type,source_type,source_id,
    currency_code,transaction_date,status,description,metadata
  ) values (
    p_organization_id,btrim(p_transaction_number),p_transaction_type,p_source_type,p_source_id,
    upper(p_currency_code),now(),'posted',p_description,
    jsonb_build_object('accounting_period_id',v_period.id)
  ) returning * into v_tx;

  insert into public.krim_ledger_entries(
    transaction_id,account_id,entry_type,amount,currency_code,description,metadata
  ) values
  (v_tx.id,v_debit.id,'debit',p_amount,upper(p_currency_code),p_description,
   jsonb_build_object('source_type',p_source_type,'source_id',p_source_id)),
  (v_tx.id,v_credit.id,'credit',p_amount,upper(p_currency_code),p_description,
   jsonb_build_object('source_type',p_source_type,'source_id',p_source_id));

  insert into public.krim_audit_events(
    actor_user_id,organization_id,event_type,entity_type,entity_id,source,
    metadata,previous_state,new_state,created_at
  ) values (
    null,p_organization_id,'ledger.transaction.posted','ledger_transaction',v_tx.id::text,
    'finance',
    jsonb_build_object('transaction_number',btrim(p_transaction_number),
      'amount',p_amount,'currency_code',upper(p_currency_code),
      'debit_account_id',v_debit.id,'credit_account_id',v_credit.id),
    null,jsonb_build_object('status','posted'),now()
  );

  return jsonb_build_object(
    'ok',true,'idempotent',false,'transaction_id',v_tx.id,
    'transaction_number',v_tx.transaction_number,'amount',p_amount,
    'currency_code',upper(p_currency_code),'balanced',true
  );
end;
$function$;

revoke all on function public.krim_internal_post_ledger_transaction(
  bigint,text,text,text,bigint,bigint,numeric,text,text,text
) from public, anon, authenticated;
grant execute on function public.krim_internal_post_ledger_transaction(
  bigint,text,text,text,bigint,bigint,numeric,text,text,text
) to service_role;

comment on function public.krim_internal_post_ledger_transaction(
  bigint,text,text,text,bigint,bigint,numeric,text,text,text
) is 'Service-role-only ledger posting with advisory-lock idempotency, replay payload verification, balanced-entry verification, tenant account checks and open-period enforcement.';

commit;
