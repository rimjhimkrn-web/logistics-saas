-- Require private dispatch proof before a warehouse custody handover can be completed.
-- The proof must be registered against this exact task, organisation and facility.
create or replace function private.krim_guard_dispatch_handover_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.task_type = 'dispatch_handover'
     and new.status = 'completed'
     and old.status is distinct from new.status then
    if new.shipment_id is null or new.shipment_leg_id is null then
      raise exception 'Dispatch handover must be linked to a shipment and shipment leg'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.krim_warehouse_evidence e
      where e.task_id = new.id
        and e.organization_id = new.organization_id
        and e.facility_id = new.facility_id
        and e.evidence_type = 'dispatch_proof'
    ) then
      raise exception 'Dispatch handover cannot be completed until dispatch proof is registered for this exact task'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$function$;

revoke all on function private.krim_guard_dispatch_handover_evidence() from public, anon, authenticated;

drop trigger if exists krim_guard_dispatch_handover_evidence on public.krim_warehouse_tasks;
create trigger krim_guard_dispatch_handover_evidence
before update of status on public.krim_warehouse_tasks
for each row
execute function private.krim_guard_dispatch_handover_evidence();
