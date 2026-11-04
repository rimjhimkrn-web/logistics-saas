revoke all on table public.partner_fleet from anon;
revoke all on table public.partner_drivers from anon;
revoke insert, update, delete on table public.partner_fleet from authenticated;
revoke insert, update, delete on table public.partner_drivers from authenticated;
grant select on table public.partner_fleet to authenticated;
grant select on table public.partner_drivers to authenticated;
alter table public.partner_fleet enable row level security;
alter table public.partner_drivers enable row level security;
