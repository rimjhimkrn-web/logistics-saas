begin;

create or replace function public.krim_guard_accounting_period_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if tg_op='TRUNCATE' then
    raise exception 'accounting_period_truncate_prohibited' using errcode='55000';
  end if;
  if tg_op='DELETE' then
    raise exception 'accounting_period_delete_prohibited: retain the audit trail' using errcode='55000';
  end if;

  if tg_op='UPDATE' then
    if old.status='closed' then
      raise exception 'closed_accounting_period_immutable' using errcode='55000';
    end if;
    if new.organization_id is distinct from old.organization_id then
      raise exception 'accounting_period_organization_immutable' using errcode='55000';
    end if;
    if old.status='open' and new.status not in ('open','closing') then
      raise exception 'invalid_accounting_period_transition: open may only remain open or enter closing' using errcode='55000';
    end if;
    if old.status='closing' and new.status not in ('closing','closed') then
      raise exception 'invalid_accounting_period_transition: closing may only remain closing or become closed' using errcode='55000';
    end if;
  end if;

  if new.period_end < new.period_start then
    raise exception 'accounting_period_end_before_start' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('accounting-period:'||new.organization_id::text,0));
  if exists (
    select 1 from public.krim_accounting_periods p
    where p.organization_id=new.organization_id
      and p.id is distinct from new.id
      and daterange(p.period_start,p.period_end,'[]') && daterange(new.period_start,new.period_end,'[]')
  ) then
    raise exception 'accounting_period_overlap_prohibited' using errcode='23P01';
  end if;

  if new.status='closed' and (new.closed_at is null or new.closed_by is null) then
    raise exception 'closed_accounting_period_requires_closed_at_and_closed_by' using errcode='23514';
  end if;
  if new.status<>'closed' and (new.closed_at is not null or new.closed_by is not null) then
    raise exception 'only_closed_accounting_period_may_have_close_metadata' using errcode='23514';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_krim_accounting_period_lifecycle on public.krim_accounting_periods;
create trigger trg_krim_accounting_period_lifecycle
before insert or update or delete on public.krim_accounting_periods
for each row execute function public.krim_guard_accounting_period_lifecycle();

drop trigger if exists trg_krim_accounting_period_no_truncate on public.krim_accounting_periods;
create trigger trg_krim_accounting_period_no_truncate
before truncate on public.krim_accounting_periods
for each statement execute function public.krim_guard_accounting_period_lifecycle();

revoke all on function public.krim_guard_accounting_period_lifecycle() from public, anon, authenticated, service_role;

comment on function public.krim_guard_accounting_period_lifecycle() is
'Protects accounting period lifecycle: serializes changes per organization, prevents overlapping periods, requires close metadata, enforces open->closing->closed transitions, and prohibits deletion/truncation or closed-period edits.';

commit;