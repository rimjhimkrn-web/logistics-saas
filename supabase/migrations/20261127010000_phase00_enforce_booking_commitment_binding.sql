-- Phase 00: enforce exact booking/commitment binding on every conversion path.
-- Staging only. No rows are created or modified by this migration.

create or replace function krim_internal.create_booking_conversion(
  p_booking_request_id bigint,
  p_commitment_id bigint,
  p_requested_by uuid,
  p_idempotency_key text
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_booking public.krim_booking_requests%rowtype;
  v_commit public.krim_commercial_commitments%rowtype;
  v_existing public.krim_booking_shipment_conversions%rowtype;
  v_id bigint;
begin
  if p_booking_request_id is null or p_commitment_id is null then
    raise exception 'booking_and_commitment_required';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'idempotency_key_required';
  end if;

  select * into v_booking
  from public.krim_booking_requests
  where id = p_booking_request_id
  for update;
  if not found then raise exception 'booking_request_not_found'; end if;
  if v_booking.organization_id is null then raise exception 'booking_organization_missing'; end if;
  if v_booking.status = 'cancelled' then raise exception 'booking_cancelled'; end if;

  select * into v_commit
  from public.krim_commercial_commitments
  where id = p_commitment_id
  for update;
  if not found then raise exception 'commercial_commitment_not_found'; end if;
  if v_commit.booking_request_id is distinct from v_booking.id then
    raise exception 'booking_commitment_mismatch';
  end if;
  if v_commit.customer_organization_id is distinct from v_booking.organization_id then
    raise exception 'organization_mismatch';
  end if;
  if v_commit.status not in ('accepted', 'active') then
    raise exception 'commitment_not_accepted';
  end if;

  select * into v_existing
  from public.krim_booking_shipment_conversions
  where booking_request_id = p_booking_request_id
    and idempotency_key = p_idempotency_key
  for update;
  if found then
    if v_existing.commercial_commitment_id is distinct from p_commitment_id then
      raise exception 'idempotency_key_reused_for_different_commitment';
    end if;
    return v_existing.id;
  end if;

  insert into public.krim_booking_shipment_conversions(
    booking_request_id, commercial_commitment_id, conversion_number, status,
    requested_by, idempotency_key, request_snapshot
  )
  values (
    p_booking_request_id, p_commitment_id,
    'KRIM-CONV-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS'),
    'pending', p_requested_by, p_idempotency_key,
    jsonb_build_object(
      'booking_request_id', p_booking_request_id,
      'commitment_id', p_commitment_id,
      'organization_id', v_booking.organization_id
    )
  )
  returning id into v_id;

  insert into public.krim_booking_shipment_conversion_events(
    conversion_id, event_type, new_status, actor_user_id, payload
  )
  values (
    v_id, 'conversion_requested', 'pending', p_requested_by,
    jsonb_build_object('idempotency_key', p_idempotency_key)
  );
  return v_id;
end;
$function$;

create or replace function krim_internal.execute_booking_shipment_conversion(
  p_conversion_id bigint,
  p_requested_by uuid,
  p_idempotency_key text
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_conv public.krim_booking_shipment_conversions%rowtype;
  v_booking public.krim_booking_requests%rowtype;
  v_commit public.krim_commercial_commitments%rowtype;
  v_shipment_org bigint;
  v_ship_id bigint;
  v_existing bigint;
begin
  if p_conversion_id is null or p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'conversion_id_and_idempotency_required';
  end if;

  select * into v_conv
  from public.krim_booking_shipment_conversions
  where id = p_conversion_id
  for update;
  if not found then raise exception 'conversion_not_found'; end if;
  if v_conv.idempotency_key is distinct from p_idempotency_key then
    raise exception 'idempotency_key_mismatch';
  end if;

  if v_conv.status = 'completed' and v_conv.shipment_id is not null then
    select customer_organization_id into v_shipment_org
    from public.krim_shipments where id = v_conv.shipment_id;
    if v_shipment_org is distinct from (
      select organization_id from public.krim_booking_requests where id = v_conv.booking_request_id
    ) then
      raise exception 'completed_conversion_shipment_organization_mismatch';
    end if;
    return v_conv.shipment_id;
  end if;
  if v_conv.status not in ('pending', 'failed') then
    raise exception 'conversion_not_executable';
  end if;

  select * into v_booking
  from public.krim_booking_requests
  where id = v_conv.booking_request_id
  for update;
  if not found then raise exception 'booking_request_not_found'; end if;
  if v_booking.organization_id is null then raise exception 'booking_organization_missing'; end if;

  select * into v_commit
  from public.krim_commercial_commitments
  where id = v_conv.commercial_commitment_id
  for update;
  if not found then raise exception 'commercial_commitment_not_found'; end if;

  if v_commit.booking_request_id is distinct from v_booking.id then
    raise exception 'booking_commitment_mismatch';
  end if;
  if v_commit.customer_organization_id is distinct from v_booking.organization_id then
    raise exception 'organization_mismatch';
  end if;
  if v_commit.status not in ('accepted', 'active') then
    raise exception 'commitment_not_accepted';
  end if;
  if v_booking.status = 'cancelled' then raise exception 'booking_cancelled'; end if;

  if v_booking.shipment_id is not null then
    select customer_organization_id into v_shipment_org
    from public.krim_shipments where id = v_booking.shipment_id;
    if v_shipment_org is distinct from v_booking.organization_id then
      raise exception 'existing_booking_shipment_organization_mismatch';
    end if;
    v_ship_id := v_booking.shipment_id;
    update public.krim_booking_shipment_conversions
    set status = 'completed', shipment_id = v_ship_id,
        result_snapshot = jsonb_build_object(
          'shipment_id', v_ship_id,
          'booking_request_id', v_booking.id,
          'commitment_id', v_commit.id,
          'reused_existing_shipment', true
        ),
        completed_at = coalesce(completed_at, now()), updated_at = now()
    where id = v_conv.id;
    return v_ship_id;
  end if;

  update public.krim_booking_shipment_conversions
  set status = 'running',
      started_at = coalesce(started_at, now()),
      requested_by = coalesce(requested_by, p_requested_by),
      updated_at = now()
  where id = v_conv.id;

  insert into public.krim_shipments(
    customer_organization_id, origin_location_id, destination_location_id,
    goods_description, total_weight_kg, status
  )
  values (
    v_booking.organization_id, v_booking.origin_location_id, v_booking.destination_location_id,
    coalesce(v_booking.cargo_summary->>'description', v_booking.cargo_summary->>'goods_description'),
    nullif(v_booking.cargo_summary->>'weight_kg', '')::numeric, 'confirmed'
  )
  returning id into v_ship_id;

  update public.krim_booking_requests
  set shipment_id = v_ship_id, status = 'accepted',
      accepted_at = coalesce(accepted_at, now()), updated_at = now()
  where id = v_booking.id;

  update public.krim_commercial_commitments
  set shipment_id = v_ship_id, status = 'active',
      effective_at = coalesce(effective_at, now()), updated_at = now()
  where id = v_commit.id;

  update public.krim_booking_shipment_conversions
  set status = 'completed', shipment_id = v_ship_id,
      result_snapshot = jsonb_build_object(
        'shipment_id', v_ship_id,
        'booking_request_id', v_booking.id,
        'commitment_id', v_commit.id
      ),
      completed_at = now(), updated_at = now()
  where id = v_conv.id;
  return v_ship_id;

exception when unique_violation then
  select shipment_id into v_existing
  from public.krim_booking_shipment_conversions
  where id = p_conversion_id;
  if v_existing is not null then return v_existing; end if;
  raise;
end;
$function$;

create or replace function krim_internal.convert_commitment_to_shipment(
  p_commitment_id bigint,
  p_requested_by uuid,
  p_idempotency_key text
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  c public.krim_commercial_commitments%rowtype;
  b public.krim_booking_requests%rowtype;
  v bigint;
begin
  if p_commitment_id is null then raise exception 'commitment_required'; end if;
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'idempotency_key_required';
  end if;

  select * into c
  from public.krim_commercial_commitments
  where id = p_commitment_id
  for update;
  if not found then raise exception 'commitment_not_found'; end if;
  if c.booking_request_id is null then
    raise exception 'commitment_booking_request_required';
  end if;

  select * into b
  from public.krim_booking_requests
  where id = c.booking_request_id
  for update;
  if not found then raise exception 'booking_request_not_found'; end if;
  if c.customer_organization_id is distinct from b.organization_id then
    raise exception 'organization_mismatch';
  end if;
  if b.status = 'cancelled' then raise exception 'booking_cancelled'; end if;
  if c.status not in ('accepted', 'active') then raise exception 'commitment_not_ready'; end if;
  if c.shipment_id is null then raise exception 'shipment_missing'; end if;

  select id into v
  from public.krim_booking_shipment_conversions
  where commercial_commitment_id = p_commitment_id
  for update;
  if v is null then
    insert into public.krim_booking_shipment_conversions(
      booking_request_id, commercial_commitment_id, shipment_id, conversion_number,
      status, requested_by, idempotency_key, request_snapshot, result_snapshot,
      started_at, completed_at
    )
    values (
      b.id, p_commitment_id, c.shipment_id,
      'KRIM-CONV-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS'),
      'completed', p_requested_by, p_idempotency_key,
      jsonb_build_object('booking_request_id', b.id, 'commitment_id', p_commitment_id),
      jsonb_build_object('shipment_id', c.shipment_id), now(), now()
    )
    returning id into v;
  else
    update public.krim_booking_shipment_conversions
    set status = 'completed', shipment_id = c.shipment_id,
        completed_at = coalesce(completed_at, now()), updated_at = now()
    where id = v
      and commercial_commitment_id = p_commitment_id
      and booking_request_id = b.id;
  end if;

  update public.krim_shipments
  set status = 'confirmed', updated_at = now()
  where id = c.shipment_id
    and customer_organization_id = b.organization_id
    and status = 'draft';

  if not found and not exists (
    select 1 from public.krim_shipments
    where id = c.shipment_id and customer_organization_id = b.organization_id
  ) then
    raise exception 'commitment_shipment_organization_mismatch';
  end if;

  update public.krim_booking_requests
  set shipment_id = c.shipment_id,
      accepted_at = coalesce(accepted_at, now()), updated_at = now()
  where id = b.id;
  update public.krim_commercial_commitments
  set status = 'active', effective_at = coalesce(effective_at, now()),
      shipment_id = c.shipment_id, updated_at = now()
  where id = c.id;
  return c.shipment_id;
end;
$function$;

revoke all on function krim_internal.create_booking_conversion(bigint,bigint,uuid,text) from public, anon, authenticated;
grant execute on function krim_internal.create_booking_conversion(bigint,bigint,uuid,text) to service_role;
revoke all on function krim_internal.execute_booking_shipment_conversion(bigint,uuid,text) from public, anon, authenticated;
grant execute on function krim_internal.execute_booking_shipment_conversion(bigint,uuid,text) to service_role;
revoke all on function krim_internal.convert_commitment_to_shipment(bigint,uuid,text) from public, anon, authenticated;
grant execute on function krim_internal.convert_commitment_to_shipment(bigint,uuid,text) to service_role;
