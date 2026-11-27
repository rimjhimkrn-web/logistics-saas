-- Phase 00: prevent terminal capacity commitment states from stranding reservations.
-- Staging only. Preserve existing finite/total/period guards.
create or replace function private.krim_guard_partner_capacity_commitment_totals()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.committed_capacity::text in ('NaN','Infinity','-Infinity')
     or new.reserved_capacity::text in ('NaN','Infinity','-Infinity')
     or new.utilized_capacity::text in ('NaN','Infinity','-Infinity') then
    raise exception using errcode='23514',
      message='Capacity commitment values must be finite';
  end if;

  if new.committed_capacity < 0
     or new.reserved_capacity < 0
     or new.utilized_capacity < 0 then
    raise exception using errcode='23514',
      message='Capacity commitment totals cannot be negative';
  end if;

  if new.reserved_capacity + new.utilized_capacity > new.committed_capacity then
    raise exception using errcode='23514',
      message='Reserved plus utilized capacity cannot exceed committed capacity';
  end if;

  if new.period_end <= new.period_start then
    raise exception using errcode='23514',
      message='Capacity commitment period end must follow start';
  end if;

  if new.status in ('cancelled','expired','completed')
     and new.reserved_capacity > 0 then
    raise exception using errcode='23514',
      message='A capacity commitment cannot become terminal while capacity remains reserved; release or reconcile reservations first';
  end if;

  return new;
end;
$function$;

comment on function private.krim_guard_partner_capacity_commitment_totals() is
  'Validates finite capacity totals, commitment periods, capacity limits, and prevents terminal status while reserved capacity remains.';
