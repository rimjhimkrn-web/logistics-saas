\set ON_ERROR_STOP on
insert into public.krim_workflows values
 (1,'shipment.lifecycle.confirmed'),(2,'shipment.lifecycle.assigned');
insert into public.krim_events values
 ('11111111-1111-1111-1111-111111111111','{"shipment_id":500,"shipment_number":"KRIM-500"}'),
 ('22222222-2222-2222-2222-222222222222','{"shipment_id":501,"shipment_number":"KRIM-501"}');
insert into public.krim_workflow_runs values
 (10,1,500,'11111111-1111-1111-1111-111111111111'),
 (11,1,500,'11111111-1111-1111-1111-111111111111'),
 (12,1,501,'22222222-2222-2222-2222-222222222222'),
 (13,2,600,'33333333-3333-3333-3333-333333333333');
insert into public.krim_events values
 ('33333333-3333-3333-3333-333333333333','{"shipment_id":600,"shipment_number":"KRIM-600"}');
insert into public.krim_workflow_run_steps values(100,'{}'),(101,'{}'),(102,'{}'),(103,'{}');
insert into public.krim_workflow_action_executions(id,workflow_run_id,action_type,request_snapshot,status)
values
 (1,10,'prepare_customer_notification','{"run_step_id":100}','queued'),
 (2,11,'prepare_customer_notification','{"run_step_id":101}','queued'),
 (3,12,'prepare_customer_notification','{"run_step_id":102}','queued'),
 (4,13,'prepare_partner_notification','{"run_step_id":103}','queued');
insert into public.handoff_test_recipients values
 (500,'customer','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','owner'),
 (500,'customer','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','operator'),
 (600,'partner','cccccccc-cccc-cccc-cccc-cccccccccccc','manager');

select public.krim_internal_execute_workflow_action(1);
do $$ begin
 if (select count(*) from public.notifications where event_id='11111111-1111-1111-1111-111111111111')<>2
 then raise exception 'expected two durable in-app notices'; end if;
 if (select count(*) from public.notifications where notification_type<>'shipment')<>0
 then raise exception 'unexpected notification type'; end if;
 if (select response_snapshot->'notification_handoff'->>'status' from public.krim_workflow_action_executions where id=1)<>'durably_recorded'
 then raise exception 'action response missing durable handoff status'; end if;
end $$;

-- A second action for the same event and users cannot duplicate notifications.
select public.krim_internal_execute_workflow_action(2);
do $$ begin
 if (select count(*) from public.notifications where event_id='11111111-1111-1111-1111-111111111111')<>2
 then raise exception 'event/user idempotency failed'; end if;
end $$;

-- No eligible recipient is an explicit recorded outcome, not a false send.
select public.krim_internal_execute_workflow_action(3);
do $$ begin
 if (select response_snapshot->'notification_handoff'->>'status' from public.krim_workflow_action_executions where id=3)<>'no_eligible_recipients'
 then raise exception 'no-recipient outcome was not explicit'; end if;
end $$;

-- Partner mapping is isolated to the assigned workflow/action pair.
select public.krim_internal_execute_workflow_action(4);
do $$ begin
 if (select count(*) from public.notifications where event_id='33333333-3333-3333-3333-333333333333' and notification_type='dispatch')<>1
 then raise exception 'partner in-app notice was not created'; end if;
end $$;
