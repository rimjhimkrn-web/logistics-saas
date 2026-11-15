CREATE OR REPLACE FUNCTION public.krim_support_ticket_set_sla_targets()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  NEW.first_response_due_at := COALESCE(NEW.created_at,now()) + interval '48 hours';
  NEW.resolution_due_at := COALESCE(NEW.created_at,now()) + interval '30 days';
  NEW.metadata := COALESCE(NEW.metadata,'{}'::jsonb)
    || pg_catalog.jsonb_build_object('support_sla_policy','KRIM_INTERNAL_48H_30D_V1');
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.krim_support_ticket_set_sla_targets() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_support_ticket_set_sla_targets ON public.support_tickets;
CREATE TRIGGER trg_support_ticket_set_sla_targets
BEFORE INSERT ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION public.krim_support_ticket_set_sla_targets();

COMMENT ON COLUMN public.support_tickets.first_response_due_at IS
  'Internal 48-hour first-response target; not a public guarantee or proof of statutory acknowledgement.';
COMMENT ON COLUMN public.support_tickets.resolution_due_at IS
  'Internal 30-day resolution target; legal applicability and actual compliance must be assessed separately.';

CREATE OR REPLACE FUNCTION public.krim_admin_transition_support_ticket(p_ticket_id bigint, p_new_status text, p_priority text, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$

