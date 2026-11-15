create or replace function private.krim_block_unallocated_multileg_finance_write()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
 if new.shipment_id is not null and exists(
  select 1 from public.krim_shipment_leg_plans p
  where p.shipment_id=new.shipment_id and p.status='active' and p.total_legs>1
 ) then
  raise exception using errcode='55000',
   message='Multi-leg shipment finance posting is held: leg-level commercial allocation, partner invoicing and KRIM fee recognition must be reconciled before invoice, payable or revenue posting';
 end if;
 return new;
end;
$function$;

revoke all on function private.krim_block_unallocated_multileg_finance_write() from public,anon,authenticated,service_role;

drop trigger if exists trg_krim_block_unallocated_multileg_invoice on public.krim_invoices;
create trigger trg_krim_block_unallocated_multileg_invoice
before insert or update of shipment_id on public.krim_invoices
for each row execute function private.krim_block_unallocated_multileg_finance_write();

drop trigger if exists trg_krim_block_unallocated_multileg_payable on public.krim_partner_payables;
create trigger trg_krim_block_unallocated_multileg_payable
before insert or update of shipment_id on public.krim_partner_payables
for each row execute function private.krim_block_unallocated_multileg_finance_write();

drop trigger if exists trg_krim_block_unallocated_multileg_revenue_allocation on public.krim_revenue_allocations;
create trigger trg_krim_block_unallocated_multileg_revenue_allocation
before insert or update of shipment_id on public.krim_revenue_allocations
for each row execute function private.krim_block_unallocated_multileg_finance_write();

drop trigger if exists trg_krim_block_unallocated_multileg_shipment_revenue on public.krim_shipment_revenue_items;
create trigger trg_krim_block_unallocated_multileg_shipment_revenue
before insert or update of shipment_id on public.krim_shipment_revenue_items
for each row execute function private.krim_block_unallocated_multileg_finance_write();
