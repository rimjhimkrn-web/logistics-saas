-- KRIM user application modules: per-user preferences, activity, export requests,
-- client error reports and safe offline queue records. Applied to project ebltviniygljwwseplph.
-- All exposed tables use RLS and bind rows to auth.uid().

create table if not exists public.krim_user_app_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint krim_user_app_preferences_object check (jsonb_typeof(preferences) = 'object'),
  constraint krim_user_app_preferences_size check (octet_length(preferences::text) <= 16384)
);
alter table public.krim_user_app_preferences enable row level security;
revoke all on public.krim_user_app_preferences from anon, public;
grant select, insert, update on public.krim_user_app_preferences to authenticated;
drop policy if exists krim_user_preferences_select_own on public.krim_user_app_preferences;
create policy krim_user_preferences_select_own on public.krim_user_app_preferences for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_user_preferences_insert_own on public.krim_user_app_preferences;
create policy krim_user_preferences_insert_own on public.krim_user_app_preferences for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists krim_user_preferences_update_own on public.krim_user_app_preferences;
create policy krim_user_preferences_update_own on public.krim_user_app_preferences for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists public.krim_user_activity_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('app_opened','preferences_saved','privacy_settings_saved','accessibility_saved','export_requested','offline_item_queued','offline_item_removed','error_reported','help_opened')),
  page_path text not null default '',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint krim_user_activity_details_object check (jsonb_typeof(details) = 'object'),
  constraint krim_user_activity_details_size check (octet_length(details::text) <= 4096),
  constraint krim_user_activity_page_size check (char_length(page_path) <= 500)
);
alter table public.krim_user_activity_events enable row level security;
revoke all on public.krim_user_activity_events from anon, public;
grant select, insert on public.krim_user_activity_events to authenticated;
drop policy if exists krim_user_activity_select_own on public.krim_user_activity_events;
create policy krim_user_activity_select_own on public.krim_user_activity_events for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_user_activity_insert_own on public.krim_user_activity_events;
create policy krim_user_activity_insert_own on public.krim_user_activity_events for insert to authenticated with check (user_id = (select auth.uid()));

create table if not exists public.krim_data_export_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  export_scope text not null check (export_scope in ('profile_and_preferences','activity_history','privacy_consent_history','account_data_request')),
  status text not null default 'queued' check (status in ('queued','processing','ready','failed','cancelled')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  result_reference text,
  failure_code text
);
alter table public.krim_data_export_requests enable row level security;
revoke all on public.krim_data_export_requests from anon, public;
grant select, insert on public.krim_data_export_requests to authenticated;
drop policy if exists krim_export_select_own on public.krim_data_export_requests;
create policy krim_export_select_own on public.krim_data_export_requests for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_export_insert_own on public.krim_data_export_requests;
create policy krim_export_insert_own on public.krim_data_export_requests for insert to authenticated with check (user_id = (select auth.uid()));

create table if not exists public.krim_client_error_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  severity text not null default 'error' check (severity in ('info','warning','error','critical')),
  message text not null check (char_length(message) between 1 and 1000),
  page_path text not null default '' check (char_length(page_path) <= 500),
  error_name text not null default '' check (char_length(error_name) <= 200),
  created_at timestamptz not null default now()
);
alter table public.krim_client_error_reports enable row level security;
revoke all on public.krim_client_error_reports from anon, public;
grant select, insert on public.krim_client_error_reports to authenticated;
drop policy if exists krim_client_errors_select_own on public.krim_client_error_reports;
create policy krim_client_errors_select_own on public.krim_client_error_reports for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_client_errors_insert_own on public.krim_client_error_reports;
create policy krim_client_errors_insert_own on public.krim_client_error_reports for insert to authenticated with check (user_id = (select auth.uid()));

create table if not exists public.krim_offline_queue_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null check (action_type in ('draft_note','retry_read_request')),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','cancelled')),
  created_at timestamptz not null default now(),
  constraint krim_offline_payload_object check (jsonb_typeof(payload) = 'object'),
  constraint krim_offline_payload_size check (octet_length(payload::text) <= 8192)
);
alter table public.krim_offline_queue_items enable row level security;
revoke all on public.krim_offline_queue_items from anon, public;
grant select, insert, delete on public.krim_offline_queue_items to authenticated;
drop policy if exists krim_offline_queue_select_own on public.krim_offline_queue_items;
create policy krim_offline_queue_select_own on public.krim_offline_queue_items for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists krim_offline_queue_insert_own on public.krim_offline_queue_items;
create policy krim_offline_queue_insert_own on public.krim_offline_queue_items for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists krim_offline_queue_delete_own on public.krim_offline_queue_items;
create policy krim_offline_queue_delete_own on public.krim_offline_queue_items for delete to authenticated using (user_id = (select auth.uid()));

create index if not exists krim_user_activity_user_created_idx on public.krim_user_activity_events(user_id, created_at desc);
create index if not exists krim_data_exports_user_requested_idx on public.krim_data_export_requests(user_id, requested_at desc);
create index if not exists krim_client_errors_user_created_idx on public.krim_client_error_reports(user_id, created_at desc);
create index if not exists krim_offline_queue_user_created_idx on public.krim_offline_queue_items(user_id, created_at desc);
