-- Transaction-safe claim/finish RPCs for the Resend email delivery worker.
-- These functions are callable only by service_role; never expose queue mutation to clients.

create or replace function public.krim_internal_claim_resend_email_batch(p_limit integer default 10)
returns table(
  outbox_id bigint,
  delivery_id bigint,
  recipient_user_id uuid,
  email_subject text,
  email_message text,
  email_payload jsonb,
  attempt_number integer,
  idempotency_key text
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_limit is null or p_limit < 1 or p_limit > 25 then
    raise exception 'p_limit must be between 1 and 25';
  end if;

  return query
  with candidates as (
    select o.id as outbox_id, d.id as delivery_id
    from public.krim_notification_outbox o
    join public.krim_notification_deliveries d
      on d.outbox_id=o.id and d.channel='email' and d.provider='resend'
    where o.channel='email'
      and o.provider='resend'
      and o.notification_type='partner_verification_information_requested'
      and o.recipient_type='user'
      and o.status in ('pending','failed')
      and d.status in ('queued','failed')
      and coalesce(d.next_attempt_at,o.next_attempt_at,o.scheduled_at)<=clock_timestamp()
      and coalesce(o.attempt_count,0)<5
      and coalesce(d.attempt_count,0)<5
      and o.recipient_reference ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and nullif(btrim(o.subject),'') is not null
      and nullif(btrim(o.message),'') is not null
    order by o.priority asc,o.scheduled_at asc,o.id asc
    for update of o,d skip locked
    limit p_limit
  ), claimed as (
    update public.krim_notification_outbox o
    set status='processing',
        attempt_count=coalesce(o.attempt_count,0)+1,
        next_attempt_at=null,
        last_error=null,
        metadata=coalesce(o.metadata,'{}'::jsonb) ||
          jsonb_build_object('worker_claimed_at',clock_timestamp(),'worker','krim-resend-v1')
    from candidates c
    where o.id=c.outbox_id
    returning o.id,o.recipient_reference::uuid as recipient_user_id,
      o.subject,o.message,o.payload,o.attempt_count,o.idempotency_key,c.delivery_id
  )
  update public.krim_notification_deliveries d
  set status='sending',
      attempt_count=coalesce(d.attempt_count,0)+1,
      next_attempt_at=null,
      last_error=null,
      updated_at=clock_timestamp()
  from claimed c
  where d.id=c.delivery_id
  returning c.id,c.delivery_id,c.recipient_user_id,c.subject,c.message,c.payload,
    c.attempt_count,c.idempotency_key;
end;
$function$;

create or replace function public.krim_internal_finish_resend_email(
  p_outbox_id bigint,
  p_delivery_id bigint,
  p_success boolean,
  p_provider_message_id text default null,
  p_error_code text default null,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_attempt integer;
  v_status text;
  v_next timestamptz;
  v_error_code text := left(coalesce(nullif(p_error_code,''),'provider_error'),80);
  v_error text := left(coalesce(nullif(p_error,''),'Email delivery failed.'),500);
begin
  if p_outbox_id is null or p_delivery_id is null or p_success is null then
    raise exception 'outbox, delivery and success values are required';
  end if;

  select o.attempt_count into v_attempt
  from public.krim_notification_outbox o
  join public.krim_notification_deliveries d
    on d.outbox_id=o.id and d.id=p_delivery_id
  where o.id=p_outbox_id
    and o.channel='email' and o.provider='resend'
    and o.notification_type='partner_verification_information_requested'
    and o.status='processing' and d.status='sending'
  for update of o,d;

  if not found then
    return jsonb_build_object('ok',false,'reason','claim_not_found');
  end if;

  if p_success then
    update public.krim_notification_outbox
    set status='sent',sent_at=clock_timestamp(),
        provider_message_id=left(nullif(coalesce(p_provider_message_id,''),''),160),
        last_error=null,next_attempt_at=null,
        metadata=coalesce(metadata,'{}'::jsonb) ||
          jsonb_build_object('provider','resend','sent_by_worker_at',clock_timestamp())
    where id=p_outbox_id;

    update public.krim_notification_deliveries
    set status='sent',sent_at=clock_timestamp(),
        provider_message_id=left(nullif(coalesce(p_provider_message_id,''),''),160),
        last_error=null,next_attempt_at=null,updated_at=clock_timestamp()
    where id=p_delivery_id;

    insert into public.krim_notification_retry_events(
      outbox_id,previous_status,new_status,attempt_number,retry_at,
      error_code,error_message,worker_id
    ) values(p_outbox_id,'processing','sent',v_attempt,null,null,null,'krim-resend-v1');

    return jsonb_build_object('ok',true,'status','sent');
  end if;

  if v_attempt>=5 then
    v_status:='dead_letter';
    v_next:=null;
  else
    v_status:='failed';
    v_next:=clock_timestamp()+make_interval(secs=>least(3600,60*power(2,greatest(0,v_attempt-1))::integer));
  end if;

  update public.krim_notification_outbox
  set status=v_status,next_attempt_at=v_next,
      last_error=v_error,
      metadata=coalesce(metadata,'{}'::jsonb) ||
        jsonb_build_object('last_provider_error_code',v_error_code,'last_failed_at',clock_timestamp())
  where id=p_outbox_id;

  update public.krim_notification_deliveries
  set status='failed',failed_at=clock_timestamp(),next_attempt_at=v_next,
      last_error=v_error,updated_at=clock_timestamp()
  where id=p_delivery_id;

  insert into public.krim_notification_retry_events(
    outbox_id,previous_status,new_status,attempt_number,retry_at,
    error_code,error_message,worker_id
  ) values(p_outbox_id,'processing',v_status,v_attempt,v_next,v_error_code,v_error,'krim-resend-v1');

  return jsonb_build_object('ok',true,'status',v_status,'next_attempt_at',v_next);
end;
$function$;

revoke all on function public.krim_internal_claim_resend_email_batch(integer) from public,anon,authenticated;
revoke all on function public.krim_internal_finish_resend_email(bigint,bigint,boolean,text,text,text) from public,anon,authenticated;
grant execute on function public.krim_internal_claim_resend_email_batch(integer) to service_role;
grant execute on function public.krim_internal_finish_resend_email(bigint,bigint,boolean,text,text,text) to service_role;
