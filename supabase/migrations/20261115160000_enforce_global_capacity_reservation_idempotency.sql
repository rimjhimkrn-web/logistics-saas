-- Enforce globally unique capacity reservation idempotency keys.
-- The reservation RPC looks up idempotency keys across the reservation table;
-- this index closes the concurrent-insert race and prevents cross-leg reuse.
create unique index if not exists uq_krim_capacity_reservations_idempotency_key
  on public.krim_capacity_reservations (idempotency_key)
  where idempotency_key is not null;

comment on index public.uq_krim_capacity_reservations_idempotency_key is
  'Prevents a capacity reservation idempotency key from being reused concurrently or across shipment legs.';
