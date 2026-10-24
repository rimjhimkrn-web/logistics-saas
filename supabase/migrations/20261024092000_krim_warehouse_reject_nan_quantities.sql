-- Reject PostgreSQL numeric NaN values so malformed direct RPC calls cannot poison stock balances.
alter table public.krim_warehouse_inventory
  add constraint krim_wh_inventory_quantity_not_nan
  check (quantity <> 'NaN'::numeric);

alter table public.krim_warehouse_inventory_movements
  add constraint krim_wh_movement_delta_not_nan
  check (quantity_delta <> 'NaN'::numeric);
