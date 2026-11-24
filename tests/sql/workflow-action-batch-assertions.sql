\set ON_ERROR_STOP on
-- Success clears only the claim's lease.
insert into public.krim_workflow_run_steps values(100,'running',null,null);
insert into public.krim_workflow_action_executions(id,status,request_snapshot,attempt_number,max_attempts)
values(1,'queued','{}',0,3);
select public.krim_internal_process_workflow_action_batch('worker-a',1,60);
do $$ begin
 if (select status from public.krim_workflow_action_executions where id=1)<>'succeeded' then raise exception 'success path did not succeed'; end if;
 if (select lease_id from public.krim_workflow_action_executions where id=1) is not null then raise exception 'success path did not clear owned lease'; end if;
end $$;
-- Ordinary executor failure schedules a bounded retry and releases lease.
update public.krim_batch_test_control set mode='raise' where singleton;
insert into public.krim_workflow_action_executions(id,status,request_snapshot,attempt_number,max_attempts)
values(2,'queued','{}',0,3);
select public.krim_internal_process_workflow_action_batch('worker-a',1,60);
do $$ begin
 if (select status from public.krim_workflow_action_executions where id=2)<>'retry_wait' then raise exception 'failure did not enter retry_wait'; end if;
 if (select lease_id from public.krim_workflow_action_executions where id=2) is not null then raise exception 'retry did not clear owned lease'; end if;
end $$;
-- Max-attempt failure is quarantined.
insert into public.krim_workflow_action_executions(id,status,request_snapshot,attempt_number,max_attempts)
values(3,'queued','{}',0,1);
select public.krim_internal_process_workflow_action_batch('worker-a',1,60);
do $$ begin
 if (select status from public.krim_workflow_action_executions where id=3)<>'failed' then raise exception 'max attempts did not fail'; end if;
 if (select dead_lettered_at from public.krim_workflow_action_executions where id=3) is null then raise exception 'max attempts did not mark dead letter'; end if;
end $$;
-- A stale worker that loses its lease must not mutate the replacement worker's row.
update public.krim_batch_test_control set mode='stale_replace' where singleton;
insert into public.krim_workflow_action_executions(id,status,request_snapshot,attempt_number,max_attempts)
values(4,'queued','{}',0,3);
select public.krim_internal_process_workflow_action_batch('worker-a',1,60);
do $$ begin
 if (select status from public.krim_workflow_action_executions where id=4)<>'running' then raise exception 'stale worker changed replacement status'; end if;
 if (select lease_id from public.krim_workflow_action_executions where id=4)<>'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid then raise exception 'stale worker changed replacement lease'; end if;
 if (select request_snapshot->>'worker_id' from public.krim_workflow_action_executions where id=4)<>'worker-b' then raise exception 'stale worker changed replacement owner'; end if;
end $$;
