-- PROPOSED ONLY. Do not apply to production until full-schema tests pass,
-- migration history is reconciled, and live recipient/provider readiness is reviewed.
-- Adds durable, idempotent in-app shipment notifications to the existing
-- lease-fenced workflow executor path. No email/SMS/WhatsApp/Telegram sends.

alter table public.notifications
  add column if not exists event_id uuid;

create unique index if not exists notifications_event_user_type_uidx
  on public.notifications(event_id, user_id, notification_type)
  where event_id is not null and user_id is not null;

-- Preserve the exact current executor as the compatibility implementation.
alter function public.krim_internal_execute_workflow_action(bigint)
  rename to krim_internal_execute_workflow_action_legacy;

create or replace function krim_internal.persist_shipment_in_app_notifications(
  p_action_execution_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_action record;
  v_mapping record;
  v_recipient record;
  v_event_payload jsonb;
  v_shipment_id bigint;
  v_event_id uuid;
  v_title text;
  v_message text;
  v_notification_type text;
  v_created integer := 0;
  v_recipient_count integer := 0;
begin
  select ae.id, ae.action_type, wr.workflow_id, wr.entity_id,
         wr.trigger_event_id, w.workflow_code, e.payload
    into v_action
  from public.krim_workflow_action_executions ae
  join public.krim_workflow_runs wr on wr.id = ae.workflow_run_id
  join public.krim_workflows w on w.id = wr.workflow_id
  left join public.krim_events e on e.event_id = wr.trigger_event_id
  where ae.id = p_action_execution_id
  for update of ae;

  if not found then
    raise exception 'workflow_action_execution_not_found' using errcode = 'P0002';
  end if;

  if v_action.action_type not in (
    'prepare_customer_notification', 'prepare_partner_notification'
  ) then
    return jsonb_build_object('status','not_applicable','created',0);
  end if;

  if v_action.trigger_event_id is null or v_action.payload is null then
    raise exception 'shipment_notification_event_context_missing' using errcode = '55000';
  end if;

  v_event_id := v_action.trigger_event_id;
  v_event_payload := v_action.payload;
  v_shipment_id := coalesce((v_event_payload->>'shipment_id')::bigint, v_action.entity_id);

  select * into v_mapping
  from krim_internal.resolve_shipment_notification_intent(
    v_action.workflow_code, v_action.action_type
  );

  v_notification_type := case v_mapping.intent_code
    when 'shipment.lifecycle.confirmed' then 'shipment'
    when 'shipment.lifecycle.dispatched' then 'dispatch'
    when 'shipment.lifecycle.delivered' then 'delivery'
    when 'shipment.lifecycle.exception' then 'alert'
    when 'shipment.lifecycle.assigned' then 'dispatch'
    else null
  end;

  if v_notification_type is null then
    raise exception 'shipment_notification_type_mapping_missing';
  end if;

  v_title := case v_mapping.intent_code
    when 'shipment.lifecycle.confirmed' then 'Shipment confirmed'
    when 'shipment.lifecycle.dispatched' then 'Shipment dispatched'
    when 'shipment.lifecycle.delivered' then 'Shipment delivered'
    when 'shipment.lifecycle.exception' then 'Shipment requires attention'
    when 'shipment.lifecycle.assigned' then 'Shipment assignment update'
  end;

  v_message := case v_mapping.intent_code
    when 'shipment.lifecycle.confirmed' then 'Your shipment has been confirmed.'
    when 'shipment.lifecycle.dispatched' then 'Your shipment has been dispatched.'
    when 'shipment.lifecycle.delivered' then 'Your shipment has been marked delivered.'
    when 'shipment.lifecycle.exception' then 'Your shipment has entered an exception state. Please review its status.'
    when 'shipment.lifecycle.assigned' then 'A shipment assignment update is available in your partner workspace.'
  end;

  for v_recipient in
    select *
    from krim_internal.resolve_shipment_notification_recipients(
      v_shipment_id, v_mapping.recipient_type, v_mapping.intent_code
    )
  loop
    v_recipient_count := v_recipient_count + 1;

    insert into public.notifications(
      user_id, shipment_id, title, message, notification_type,
      is_read, created_at, krim_shipment_id, event_id
    ) values (
      v_recipient.user_id, null, v_title, v_message, v_notification_type,
      false, clock_timestamp(), v_shipment_id, v_event_id
    )
    on conflict (event_id, user_id, notification_type)
      where event_id is not null and user_id is not null
    do nothing;

    get diagnostics v_created = row_count;
    -- Accumulate inserted rows without confusing conflict/no-op with delivery.
    v_created := v_created;
  end loop;

  return jsonb_build_object(
    'status', case when v_recipient_count = 0 then 'no_eligible_recipients'
                   else 'durably_recorded' end,
    'recipient_count', v_recipient_count,
    'created', (
      select count(*)::integer
      from public.notifications n
      where n.event_id = v_event_id
        and n.notification_type = v_notification_type
    ),
    'event_id', v_event_id,
    'channel', 'in_app'
  );
end;
$function$;

revoke all on function krim_internal.persist_shipment_in_app_notifications(bigint) from public;
revoke all on function krim_internal.persist_shipment_in_app_notifications(bigint) from anon;
revoke all on function krim_internal.persist_shipment_in_app_notifications(bigint) from authenticated;
grant execute on function krim_internal.persist_shipment_in_app_notifications(bigint) to service_role;

-- Wrapper preserves the established executor behavior and appends the durable
-- in-app handoff in the same transaction. Any handoff error rolls back both.
create or replace function public.krim_internal_execute_workflow_action(
  p_action_execution_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $function$
declare
  v_result jsonb;
  v_handoff jsonb;
  v_step_id bigint;
begin
  v_result := public.krim_internal_execute_workflow_action_legacy(p_action_execution_id);

  if coalesce(v_result->>'status','') = 'succeeded' then
    v_handoff := krim_internal.persist_shipment_in_app_notifications(p_action_execution_id);

    select (request_snapshot->>'run_step_id')::bigint
      into v_step_id
    from public.krim_workflow_action_executions
    where id = p_action_execution_id;

    update public.krim_workflow_action_executions
    set response_snapshot = coalesce(response_snapshot,'{}'::jsonb)
          || jsonb_build_object('notification_handoff',v_handoff),
        updated_at = clock_timestamp()
    where id = p_action_execution_id;

    update public.krim_workflow_run_steps
    set result = coalesce(result,'{}'::jsonb)
          || jsonb_build_object('notification_handoff',v_handoff)
    where id = v_step_id;
    
    v_result := v_result || jsonb_build_object('notification_handoff',v_handoff);
  end if;

  return v_result;
end;
$function$;

revoke all on function public.krim_internal_execute_workflow_action(bigint) from public;
revoke all on function public.krim_internal_execute_workflow_action(bigint) from anon;
revoke all on function public.krim_internal_execute_workflow_action(bigint) from authenticated;
grant execute on function public.krim_internal_execute_workflow_action(bigint) to service_role;

comment on function krim_internal.persist_shipment_in_app_notifications(bigint)
is 'Creates idempotent durable in-app shipment notices for verified resolver recipients; no external delivery.';

comment on function public.krim_internal_execute_workflow_action(bigint)
is 'Compatibility wrapper: legacy workflow executor plus transactional idempotent in-app shipment notification handoff.';
