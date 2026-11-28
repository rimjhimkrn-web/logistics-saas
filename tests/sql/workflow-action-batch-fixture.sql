-- Isolated fixture for the proposed workflow action batch replacement.
-- Uses synthetic rows only; never connects to KRIM production.
create schema if not exists krim_internal;
create table public.krim_workflow_action_executions (
 id bigint primary key, status text not null, lease_id uuid, lease_expires_at timestamptz,
 request_snapshot jsonb not null default '{}'::jsonb, attempt_number integer not null default 0,
 max_attempts integer not null default 3, next_retry_at timestamptz, error_code text,
 error_message text, dead_lettered_at timestamptz, updated_at timestamptz
);
create table public.krim_workflow_run_steps (
 id bigint primary key, status text not null, error_message text, completed_at timestamptz
);
create table public.krim_batch_test_control (
 singleton boolean primary key default true check(singleton), mode text not null,
 response jsonb not null default '{"ok":true,"status":"succeeded"}'::jsonb
);
insert into public.krim_batch_test_control(singleton,mode) values(true,'success');
create function public.krim_internal_recover_expired_workflow_actions(integer)
returns integer language sql as $$ select 0 $$;
create function public.krim_internal_claim_workflow_actions(p_worker_id text,p_limit integer,p_lease_seconds integer)
returns table(action_execution_id bigint,lease_id uuid,action_type text)
language plpgsql as $$
declare v_id bigint; v_lease uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
begin
 select id into v_id from public.krim_workflow_action_executions where status='queued' or (status='retry_wait' and coalesce(next_retry_at,clock_timestamp())<=clock_timestamp()) order by id limit 1;
 if v_id is null then return; end if;
 update public.krim_workflow_action_executions ae
 set status='running',lease_id=v_lease,lease_expires_at=clock_timestamp()+make_interval(secs=>greatest(60,p_lease_seconds)),
 request_snapshot=ae.request_snapshot||jsonb_build_object('worker_id',p_worker_id,'run_step_id',100),
 updated_at=clock_timestamp()
 where ae.id=v_id;
 if (select mode from public.krim_batch_test_control where singleton)='stale_replace' then
   update public.krim_workflow_action_executions set lease_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
     request_snapshot=jsonb_set(request_snapshot,'{worker_id}','"worker-b"') where id=v_id;
 end if;
 action_execution_id:=v_id; lease_id:=v_lease; action_type:='test_action'; return next;
end $$;
create function krim_internal.execute_workflow_action_fenced(p_action_execution_id bigint,p_lease_id uuid,p_worker_id text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $fixture$
declare a public.krim_workflow_action_executions%rowtype; v_mode text; v_response jsonb;
begin
 select * into a from public.krim_workflow_action_executions where id=p_action_execution_id for update;
 if a.status<>'running' or a.lease_id is distinct from p_lease_id
    or a.request_snapshot->>'worker_id' is distinct from p_worker_id
    or a.lease_expires_at<=clock_timestamp() then
   raise exception 'workflow_action_lease_stale_or_not_owned';
 end if;
 select mode,response into v_mode,v_response from public.krim_batch_test_control where singleton;
 begin
   update public.krim_workflow_action_executions
   set attempt_number=attempt_number+1,status='succeeded'
   where id=p_action_execution_id;
   if v_mode='raise' then
     raise exception 'simulated executor failure';
   end if;
   return v_response;
 exception when others then
   -- Mirror the live executor's exception handler: the increment above rolls
   -- back with this block, while the failed status survives in the handler.
   update public.krim_workflow_action_executions
   set status='failed',error_message=sqlerrm
   where id=p_action_execution_id;
   raise;
 end;
end $fixture$;
create function public.krim_internal_quarantine_workflow_action(bigint,text)
returns bigint language sql as $$ select 1::bigint $$;
