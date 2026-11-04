-- Per-user rate limit for authenticated KRIM AI requests.
create table if not exists private.krim_ai_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null default 0 check (request_count between 0 and 21),
  updated_at timestamptz not null default now()
);

alter table private.krim_ai_rate_limits enable row level security;
revoke all on table private.krim_ai_rate_limits from public, anon, authenticated;

create or replace function public.krim_consume_ai_rate_limit()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_request_count integer;
  v_now timestamptz := pg_catalog.now();
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  insert into private.krim_ai_rate_limits(user_id, window_started_at, request_count, updated_at)
  values (v_user_id, v_now, 1, v_now)
  on conflict (user_id) do update
    set window_started_at = case
          when v_now - private.krim_ai_rate_limits.window_started_at >= interval '10 minutes'
            then v_now
          else private.krim_ai_rate_limits.window_started_at
        end,
        request_count = case
          when v_now - private.krim_ai_rate_limits.window_started_at >= interval '10 minutes'
            then 1
          else least(private.krim_ai_rate_limits.request_count + 1, 21)
        end,
        updated_at = v_now
  returning request_count into v_request_count;

  return v_request_count <= 20;
end;
$$;

revoke all on function public.krim_consume_ai_rate_limit() from public, anon;
grant execute on function public.krim_consume_ai_rate_limit() to authenticated;
