-- Secure customer/administrator support conversation and status workflow.
-- Customers can reply only to tickets they created. Internal notes are admin-only.
drop policy if exists "KRIM support messages organization access" on public.krim_support_ticket_messages;
create policy "KRIM support message owner read"
on public.krim_support_ticket_messages
for select to authenticated
using (
  is_internal = false
  and exists (
    select 1 from public.support_tickets t
    where t.id = krim_support_ticket_messages.ticket_id
      and t.user_id = (select auth.uid())
  )
);

drop policy if exists "KRIM support events organization access" on public.krim_support_ticket_events;
create policy "KRIM support event owner read"
on public.krim_support_ticket_events
for select to authenticated
using (
  exists (
    select 1 from public.support_tickets t
    where t.id = krim_support_ticket_events.ticket_id
      and t.user_id = (select auth.uid())
  )
);

create or replace function public.krim_customer_reply_support_ticket(
  p_ticket_id bigint,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_message_id bigint;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if p_ticket_id is null or nullif(btrim(p_body),'') is null
     or char_length(btrim(p_body)) < 2 or char_length(btrim(p_body)) > 5000 then
    raise exception using errcode='22023', message='Message must contain 2–5000 characters';
  end if;

  select * into v_ticket
  from public.support_tickets
  where id=p_ticket_id and user_id=v_user
  for update;

  if not found then
    raise exception using errcode='42501', message='Support ticket not found or not owned by this account';
  end if;
  if v_ticket.status in ('resolved','closed') then
    raise exception using errcode='55000', message='This support ticket is closed. Create a new ticket if you need further help.';
  end if;

  insert into public.krim_support_ticket_messages
    (ticket_id,sender_user_id,sender_organization_id,message_type,body,is_internal)
  values
    (v_ticket.id,v_user,v_ticket.krim_organization_id,'comment',btrim(p_body),false)
  returning id into v_message_id;

  update public.support_tickets
  set updated_at=now(),last_customer_update_at=now()
  where id=v_ticket.id;

  insert into public.krim_support_ticket_events
    (ticket_id,event_type,actor_user_id,previous_status,new_status,metadata)
  values
    (v_ticket.id,'customer_reply',v_user,v_ticket.status,v_ticket.status,
     jsonb_build_object('message_id',v_message_id));

  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user,v_ticket.krim_organization_id,'support.ticket.customer_reply','support_ticket',v_ticket.id::text,
     'customer_support',jsonb_build_object('message_id',v_message_id),
     jsonb_build_object('status',v_ticket.status),jsonb_build_object('status',v_ticket.status));

  return jsonb_build_object('success',true,'ticket_id',v_ticket.id,'message_id',v_message_id);
end;
$function$;

create or replace function public.krim_admin_list_support_tickets(
  p_status text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_items jsonb;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='AAL2 multi-factor authentication is required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_status is not null and p_status not in ('open','in_progress','resolved','closed') then
    raise exception using errcode='22023', message='Unsupported support status filter';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
  into v_items
  from (
    select t.id,t.ticket_number,t.user_id,u.email user_email,t.krim_organization_id,
      o.legal_name organization_name,t.krim_shipment_id,s.shipment_number,
      t.category,t.subject,t.status,t.priority,t.created_at,t.updated_at,
      t.first_response_due_at,t.resolution_due_at,t.first_responded_at,
      t.resolved_at,t.closed_at,t.assigned_to,t.assigned_organization_id,
      t.escalation_level,t.escalation_reason,
      (select count(*) from public.krim_support_ticket_messages m where m.ticket_id=t.id) message_count,
      (select max(m.created_at) from public.krim_support_ticket_messages m where m.ticket_id=t.id and m.is_internal=false) last_customer_message_at
    from public.support_tickets t
    left join auth.users u on u.id=t.user_id
    left join public.krim_organizations o on o.id=t.krim_organization_id
    left join public.krim_shipments s on s.id=t.krim_shipment_id
    where p_status is null or t.status=p_status
    order by t.created_at desc
    limit least(greatest(coalesce(p_limit,50),1),100)
  ) x;

  return jsonb_build_object('items',v_items,'count',jsonb_array_length(v_items));
end;
$function$;

create or replace function public.krim_admin_get_support_ticket_thread(p_ticket_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_ticket jsonb;
  v_messages jsonb;
  v_events jsonb;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='AAL2 multi-factor authentication is required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if not exists(select 1 from public.support_tickets where id=p_ticket_id) then
    raise exception using errcode='P0002', message='Support ticket not found';
  end if;

  select to_jsonb(t)||jsonb_build_object('user_email',u.email,'organization_name',o.legal_name,'shipment_number',s.shipment_number)
  into v_ticket
  from public.support_tickets t
  left join auth.users u on u.id=t.user_id
  left join public.krim_organizations o on o.id=t.krim_organization_id
  left join public.krim_shipments s on s.id=t.krim_shipment_id
  where t.id=p_ticket_id;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at),'[]'::jsonb)
  into v_messages
  from public.krim_support_ticket_messages m
  where m.ticket_id=p_ticket_id;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at),'[]'::jsonb)
  into v_events
  from public.krim_support_ticket_events e
  where e.ticket_id=p_ticket_id;

  return jsonb_build_object('ticket',v_ticket,'messages',v_messages,'events',v_events);
end;
$function$;

create or replace function public.krim_admin_reply_support_ticket(
  p_ticket_id bigint,
  p_body text,
  p_internal boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_message_id bigint;
  v_new_status text;
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='AAL2 multi-factor authentication is required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_ticket_id is null or nullif(btrim(p_body),'') is null
     or char_length(btrim(p_body)) < 2 or char_length(btrim(p_body)) > 5000 then
    raise exception using errcode='22023', message='Message must contain 2–5000 characters';
  end if;

  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if not found then raise exception using errcode='P0002', message='Support ticket not found'; end if;
  if coalesce(p_internal,false)=false and v_ticket.status in ('resolved','closed') then
    raise exception using errcode='55000', message='Reopen the ticket before sending a customer-visible reply';
  end if;

  insert into public.krim_support_ticket_messages
    (ticket_id,sender_user_id,sender_organization_id,message_type,body,is_internal)
  values
    (v_ticket.id,v_user,null,case when coalesce(p_internal,false) then 'system' else 'comment' end,btrim(p_body),coalesce(p_internal,false))
  returning id into v_message_id;

  v_new_status:=case when not coalesce(p_internal,false) and v_ticket.status='open' then 'in_progress' else v_ticket.status end;

  update public.support_tickets
  set status=v_new_status,
      assigned_to=case when not coalesce(p_internal,false) then coalesce(assigned_to,v_user) else assigned_to end,
      first_responded_at=case when not coalesce(p_internal,false) then coalesce(first_responded_at,now()) else first_responded_at end,
      updated_at=now()
  where id=v_ticket.id;

  insert into public.krim_support_ticket_events
    (ticket_id,event_type,actor_user_id,previous_status,new_status,metadata)
  values
    (v_ticket.id,case when coalesce(p_internal,false) then 'admin_internal_note' else 'admin_reply' end,
     v_user,v_ticket.status,v_new_status,jsonb_build_object('message_id',v_message_id));

  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user,v_ticket.krim_organization_id,
     case when coalesce(p_internal,false) then 'support.ticket.internal_note' else 'support.ticket.admin_reply' end,
     'support_ticket',v_ticket.id::text,'platform_admin',
     jsonb_build_object('message_id',v_message_id,'internal',coalesce(p_internal,false)),
     jsonb_build_object('status',v_ticket.status),jsonb_build_object('status',v_new_status));

  return jsonb_build_object('success',true,'ticket_id',v_ticket.id,'message_id',v_message_id,'status',v_new_status);
end;
$function$;

create or replace function public.krim_admin_transition_support_ticket(
  p_ticket_id bigint,
  p_new_status text,
  p_priority text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
begin
  if v_user is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='AAL2 multi-factor authentication is required';
  end if;
  if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;
  if p_ticket_id is null or p_new_status not in ('open','in_progress','resolved','closed') then
    raise exception using errcode='22023', message='Choose a valid support status';
  end if;
  if p_priority is not null and p_priority not in ('low','normal','high','urgent') then
    raise exception using errcode='22023', message='Choose a valid support priority';
  end if;
  if p_new_status in ('resolved','closed') and char_length(coalesce(v_reason,''))<5 then
    raise exception using errcode='22023', message='A resolution or closure reason of at least 5 characters is required';
  end if;

  select * into v_ticket from public.support_tickets where id=p_ticket_id for update;
  if not found then raise exception using errcode='P0002', message='Support ticket not found'; end if;
  if v_ticket.status in ('resolved','closed') and p_new_status in ('resolved','closed') and p_new_status=v_ticket.status then
    raise exception using errcode='55000', message='Ticket already has this terminal status';
  end if;

  update public.support_tickets
  set status=p_new_status,
      priority=coalesce(p_priority,priority),
      first_responded_at=case when p_new_status in ('in_progress','resolved','closed') then coalesce(first_responded_at,now()) else first_responded_at end,
      resolved_at=case when p_new_status='resolved' then coalesce(resolved_at,now()) when p_new_status='open' or p_new_status='in_progress' then null else resolved_at end,
      closed_at=case when p_new_status='closed' then coalesce(closed_at,now()) when p_new_status='open' or p_new_status='in_progress' then null else closed_at end,
      updated_at=now(),
      escalation_reason=case when v_reason is not null then v_reason else escalation_reason end
  where id=p_ticket_id;

  insert into public.krim_support_ticket_events
    (ticket_id,event_type,actor_user_id,previous_status,new_status,metadata)
  values
    (p_ticket_id,'status_changed',v_user,v_ticket.status,p_new_status,
     jsonb_build_object('priority',coalesce(p_priority,v_ticket.priority),'reason',v_reason));

  insert into public.krim_audit_events
    (actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
  values
    (v_user,v_ticket.krim_organization_id,'support.ticket.status_changed','support_ticket',p_ticket_id::text,'platform_admin',
     jsonb_build_object('priority',coalesce(p_priority,v_ticket.priority),'reason',v_reason),
     jsonb_build_object('status',v_ticket.status,'priority',v_ticket.priority),
     jsonb_build_object('status',p_new_status,'priority',coalesce(p_priority,v_ticket.priority)));

  return jsonb_build_object('success',true,'ticket_id',p_ticket_id,'status',p_new_status,'priority',coalesce(p_priority,v_ticket.priority));
end;
$function$;

revoke all on function public.krim_customer_reply_support_ticket(bigint,text) from public, anon;
revoke all on function public.krim_admin_list_support_tickets(text,integer) from public, anon;
revoke all on function public.krim_admin_get_support_ticket_thread(bigint) from public, anon;
revoke all on function public.krim_admin_reply_support_ticket(bigint,text,boolean) from public, anon;
revoke all on function public.krim_admin_transition_support_ticket(bigint,text,text,text) from public, anon;
grant execute on function public.krim_customer_reply_support_ticket(bigint,text) to authenticated;
grant execute on function public.krim_admin_list_support_tickets(text,integer) to authenticated;
grant execute on function public.krim_admin_get_support_ticket_thread(bigint) to authenticated;
grant execute on function public.krim_admin_reply_support_ticket(bigint,text,boolean) to authenticated;
grant execute on function public.krim_admin_transition_support_ticket(bigint,text,text,text) to authenticated;
