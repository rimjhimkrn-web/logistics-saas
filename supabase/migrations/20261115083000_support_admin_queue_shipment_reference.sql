CREATE OR REPLACE FUNCTION public.krim_admin_list_support_tickets(p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      t.category,t.subject,t.status,t.priority,t.created_at,t.updated_at,t.tracking_number,
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
$function$

