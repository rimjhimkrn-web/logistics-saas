-- Configure the finance control organization's INR account-role mappings.
-- This is configuration only: it creates no journal entries, balances, invoices, refunds or payouts.
do $$
declare
  v_org_id bigint := 21;
  v_currency text := 'INR';
  v_bank bigint;
  v_receivable bigint;
  v_revenue bigint;
  v_partner_payable bigint;
  v_partner_funds bigint;
begin
  if not exists (
    select 1 from public.krim_organizations
    where id=v_org_id and organization_type='finance' and status='active'
  ) then
    raise exception 'active_finance_organization_missing';
  end if;
  if not exists (select 1 from public.krim_currencies where code=v_currency and is_active=true) then
    raise exception 'active_INR_currency_missing';
  end if;

  select id into v_bank from public.krim_ledger_accounts
   where organization_id=v_org_id and account_code='1010' and currency_code=v_currency and status='active';
  select id into v_receivable from public.krim_ledger_accounts
   where organization_id=v_org_id and account_code='1100' and currency_code=v_currency and status='active';
  select id into v_revenue from public.krim_ledger_accounts
   where organization_id=v_org_id and account_code='4000' and currency_code=v_currency and status='active';
  select id into v_partner_payable from public.krim_ledger_accounts
   where organization_id=v_org_id and account_code='2000' and currency_code=v_currency and status='active';
  select id into v_partner_funds from public.krim_ledger_accounts
   where organization_id=v_org_id and account_code='1000' and currency_code=v_currency and status='active';

  if v_bank is null or v_receivable is null or v_revenue is null or v_partner_payable is null or v_partner_funds is null then
    raise exception 'required_active_INR_chart_accounts_missing';
  end if;

  insert into public.krim_accounting_account_mappings
    (organization_id,account_role,account_id,currency_code,status,metadata)
  values
    (v_org_id,'bank',v_bank,v_currency,'active',jsonb_build_object('mapping_basis','Razorpay clearing account 1010','version',1)),
    (v_org_id,'receivable',v_receivable,v_currency,'active',jsonb_build_object('mapping_basis','Trade accounts receivable 1100','version',1)),
    (v_org_id,'revenue',v_revenue,v_currency,'active',jsonb_build_object('mapping_basis','Freight service revenue 4000; tax and commission split requires separate approved rules','version',1)),
    (v_org_id,'partner_payable',v_partner_payable,v_currency,'active',jsonb_build_object('mapping_basis','Partner payables 2000','version',1)),
    (v_org_id,'partner_funds',v_partner_funds,v_currency,'active',jsonb_build_object('mapping_basis','Cash and bank 1000; partner payout cash account','version',1))
  on conflict (organization_id,account_role,currency_code)
  do update set account_id=excluded.account_id,status='active',metadata=excluded.metadata,updated_at=now();

  if (select count(*) from public.krim_accounting_account_mappings
      where organization_id=v_org_id and currency_code=v_currency and status='active') < 5 then
    raise exception 'finance_INR_account_mapping_incomplete';
  end if;

  perform public.krim_internal_provision_standard_posting_rules(v_org_id,v_currency);
end $$;
