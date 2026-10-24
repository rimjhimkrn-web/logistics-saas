create table if not exists public.krim_inquiry_followups (
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null references public.krim_public_contact_inquiries(id) on delete cascade,
  note text not null check (char_length(btrim(note)) between 1 and 2000),
  follow_up_at timestamptz,
  outcome text not null default 'pending' check (outcome in ('pending','contacted','qualified','not_interested','converted')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists krim_inquiry_followups_inquiry_created_idx
  on public.krim_inquiry_followups (inquiry_id, created_at desc);
create index if not exists krim_inquiry_followups_due_idx
  on public.krim_inquiry_followups (follow_up_at)
  where follow_up_at is not null and outcome = 'pending';
alter table public.krim_inquiry_followups enable row level security;
revoke all on table public.krim_inquiry_followups from anon, authenticated;
grant all on table public.krim_inquiry_followups to service_role;
