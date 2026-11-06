create or replace function private.krim_refund_request_submit(p_payment_order_id uuid,p_amount_paise bigint,p_reason text,p_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid();v_order public.payment_orders%rowtype;v_existing public.krim_refund_requests%rowtype;v_id uuid;
begin
 if v_user is null then raise exception 'Authentication required';end if;
 if p_idempotency_key is null then raise exception 'Idempotency key is required';end if;
 if p_amount_paise is null or p_amount_paise<=0 then raise exception 'Refund amount must be positive';end if;
 if length(trim(coalesce(p_reason,'')))<20 then raise exception 'Please provide a reason of at least 20 characters';end if;
 select * into v_order from public.payment_orders where id=p_payment_order_id for update;
 if not found then raise exception 'Payment order not found';end if;
 -- Until provider refunds are reconciled to a remaining refundable balance, only
 -- fully paid, not-yet-refunded orders are eligible. Fail closed on partial refunds.
 if v_order.status<>'paid' then raise exception 'Only fully paid, not-yet-refunded payment orders can be submitted for refund';end if;
 if v_order.customer_id<>v_user and not exists(select 1 from public.krim_organization_members m where m.organization_id=v_order.customer_organization_id and m.user_id=v_user and m.status='active') then raise exception 'Payment order does not belong to this customer';end if;
 if p_amount_paise>v_order.amount_paise then raise exception 'Refund request cannot exceed the original payment amount';end if;
 select * into v_existing from public.krim_refund_requests where payment_order_id=p_payment_order_id;
 if found then
  if v_existing.customer_user_id=v_user and v_existing.idempotency_key=p_idempotency_key then return v_existing.id;end if;
  raise exception 'A refund request already exists for this payment order; contact finance for an update';
 end if;
 select id into v_id from public.krim_refund_requests where idempotency_key=p_idempotency_key;
 if v_id is not null then raise exception 'Idempotency key has already been used';end if;
 insert into public.krim_refund_requests(payment_order_id,customer_organization_id,customer_user_id,amount_paise,reason,idempotency_key)
 values(p_payment_order_id,v_order.customer_organization_id,v_user,p_amount_paise,left(trim(p_reason),4000),p_idempotency_key) returning id into v_id;
 insert into public.krim_refund_request_events(refund_request_id,event_type,actor_user_id,actor_organization_id,event_note,event_data)
 values(v_id,'submitted',v_user,v_order.customer_organization_id,'Customer submitted a refund request.',jsonb_build_object('payment_order_id',p_payment_order_id,'amount_paise',p_amount_paise));
 return v_id;
end;$function$;
revoke all on function private.krim_refund_request_submit(uuid,bigint,text,uuid) from public,anon,authenticated;
grant execute on function private.krim_refund_request_submit(uuid,bigint,text,uuid) to authenticated;
