-- Synthetic PostgreSQL fixture for the proposed in-app notification handoff.
-- No production data, credentials or provider calls.
create schema if not exists krim_internal;

create table public.krim_workflows(id bigint primary key, workflow_code text not null);
create table public.krim_workflow_runs(
 id bigint primary key, workflow_id bigint not null, entity_id bigint not null,
 trigger_event_id uuid
);
create table public.krim_workflow_action_executions(
 id bigint primary key, workflow_run_id bigint not null, action_type text not null,
 request_snapshot jsonb not null default '{}', response_snapshot jsonb not null default '{}',
 status text not null, updated_at timestamptz not null default clock_timestamp()
);
create table public.krim_workflow_run_steps(
 id bigint primary key, result jsonb not null default '{}'
);
create table public.krim_events(event_id uuid primary key,payload jsonb not null);
create table public.notifications(
 id bigserial primary key, user_id uuid not null, shipment_id bigint,
 title text not null, message text not null, notification_type text not null
 check(notification_type in ('general','shipment','quote','payment','dispatch','delivery','alert')),
 is_read boolean not null default false, created_at timestamptz not null default clock_timestamp(),
 krim_shipment_id bigint, event_id uuid
);
create unique index notifications_event_user_type_uidx
 on public.notifications(event_id,user_id,notification_type)
 where event_id is not null and user_id is not null;

create table public.handoff_test_recipients(
 shipment_id bigint, recipient_type text, user_id uuid, role text
);

create function krim_internal.resolve_shipment_notification_intent(p_workflow_code text,p_action_type text)
returns table(recipient_type text,intent_code text)
language plpgsql immutable as $$
begin
 if p_workflow_code='shipment.lifecycle.confirmed' and p_action_type='prepare_customer_notification' then
  return query select 'customer'::text,'shipment.lifecycle.confirmed'::text; return;
 elsif p_workflow_code='shipment.lifecycle.assigned' and p_action_type='prepare_partner_notification' then
  return query select 'partner'::text,'shipment.lifecycle.assigned'::text; return;
 else raise exception 'unsupported_workflow_notification_mapping'; end if;
end $$;

create function krim_internal.resolve_shipment_notification_recipients(
 p_shipment_id bigint,p_recipient_type text,p_intent_code text
)
returns table(recipient_type text,organization_id bigint,user_id uuid,member_role text,
 resolution_source text,preferred_language_code text,timezone text)
language sql stable as $$
 select p_recipient_type,1::bigint,r.user_id,r.role,'synthetic_verified_fixture'::text,'en'::text,'Asia/Kolkata'::text
 from public.handoff_test_recipients r
 where r.shipment_id=p_shipment_id and r.recipient_type=p_recipient_type
$$;

create function public.krim_internal_execute_workflow_action(p_action_execution_id bigint)
returns jsonb language plpgsql as $$
begin
 update public.krim_workflow_action_executions
 set status='succeeded',response_snapshot='{"legacy":"done"}'::jsonb,updated_at=clock_timestamp()
 where id=p_action_execution_id;
 return jsonb_build_object('ok',true,'status','succeeded','action_execution_id',p_action_execution_id);
end $$;
