-- Stock balances and movement audit records may only be changed through the validated atomic RPC.
revoke insert, update, delete on public.krim_warehouse_inventory from authenticated;
grant select on public.krim_warehouse_inventory to authenticated;

drop policy if exists krim_wh_movements_insert_member on public.krim_warehouse_inventory_movements;
revoke insert, update, delete on public.krim_warehouse_inventory_movements from authenticated;
grant select on public.krim_warehouse_inventory_movements to authenticated;

comment on function public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)
is 'Validated atomic stock balance and append-only movement operation. Client roles must not write inventory or movement tables directly.';
