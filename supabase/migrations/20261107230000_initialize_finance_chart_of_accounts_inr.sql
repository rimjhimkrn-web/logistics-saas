-- Initialize KRIM's finance control organization with a base INR chart of accounts.
-- This creates account definitions only: no balances, journal entries, revenue, or payouts.
do $$
declare v_finance_org_id bigint; v_count integer;
begin
 select id into v_finance_org_id
 from public.krim_organizations
 where organization_type='finance' and status='active'
 order by id
 limit 1;
 if v_finance_org_id is null then
   raise notice 'No active finance organization found; chart initialization skipped.';
   return;
 end if;
 update public.krim_organizations
 set default_currency_code='INR',updated_at=now()
 where id=v_finance_org_id and default_currency_code is null;
 if not exists(select 1 from public.krim_currencies where code='INR' and is_active=true) then
   raise exception 'INR currency is not active; chart initialization aborted.';
 end if;
 insert into public.krim_ledger_accounts
  (organization_id,account_code,account_name,account_type,normal_balance,currency_code,status,metadata)
 values
  (v_finance_org_id,'1000','Cash and Bank','asset','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'1010','Razorpay Payment Clearing','asset','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1,"provider":"razorpay"}'::jsonb),
  (v_finance_org_id,'1100','Trade Accounts Receivable','asset','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'1200','Input GST Credit','asset','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1,"tax":"GST"}'::jsonb),
  (v_finance_org_id,'2000','Partner Payables','liability','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'2010','Output GST Payable','liability','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1,"tax":"GST"}'::jsonb),
  (v_finance_org_id,'2020','Customer Funds Held / Unearned Revenue','liability','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'3000','Proprietor Capital','equity','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'3100','Retained Earnings','equity','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'4000','Freight and Logistics Service Revenue','revenue','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'4010','KRIM Platform Commission Revenue','revenue','credit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'4090','Refunds and Customer Credits','revenue','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1,"contra_revenue":true}'::jsonb),
  (v_finance_org_id,'5000','Operating Expenses','expense','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb),
  (v_finance_org_id,'5010','Payment Gateway Fees','expense','debit','INR','active','{"chart":"KRIM-BASE-INR","version":1}'::jsonb)
 on conflict (organization_id,account_code,currency_code) do nothing;
 select count(*) into v_count from public.krim_ledger_accounts where organization_id=v_finance_org_id and currency_code='INR';
 if v_count<14 then raise exception 'Finance chart initialization incomplete: expected at least 14 INR accounts, found %',v_count; end if;
end $$;
