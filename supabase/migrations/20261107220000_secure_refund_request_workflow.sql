create table if not exists public.krim_refund_requests (
 id uuid primary key default gen_random_uuid(),
 payment_order_id uuid not null references public.payment_orders(id) on delete restrict,
 customer_organization_id bigint references public.krim_organizations(id) on delete restrict,
 customer_user_id uuid not null references auth.users(id) on delete restrict,
 amount_paise bigint not null check(amount_paise>0),
 reason text not null check(length(trim(reason)) between 20 and 4000),
 idempotency_key uuid not null,
 status text not null default 'submitted' check(status in ('submitted','under_review','approved_pending_execution','rejected','execution_pending','processed','failed','cancelled')),
 requested_at timestamptz not null default now(),
 reviewed_by uuid references auth.users(id) on delete restrict,
 reviewer_organization_id bigint references public.krim_organizations(id) on delete restrict,
 reviewed_at timestamptz,
 review_note text,
 provider_refund_id text unique,
 provider_status text,
 processed_at timestamptz,
 failure_reason text,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint krim_refund_request_one_per_payment unique(payment_order_id),
 constraint krim_refund_request_review_fields check (
  (reviewed_at is null and reviewed_by is null and reviewer_organization_id is null)
  or (reviewed_at is not null and reviewed_by is not null and reviewer_organization_id is not null)
 )
);
create unique index if not exists krim_refund_requests_idempotency_key_uq on public.krim_refund_requests(idempotency_key);
create index if not exists krim_refund_requests_status_created_idx on public.krim_refund_requests(status,created_at desc);
alter table public.krim_refund_requests enable row level security;
alter table public.krim_refund_requests force row level security;
revoke all on public.krim_refund_requests from public,anon,authenticated;
grant select on public.krim_refund_requests to authenticated;
drop policy if exists "KRIM refund requests participant read" on public.krim_refund_requests;
create policy "KRIM refund requests participant read" on public.krim_refund_requests
 for select to authenticated using (
  customer_user_id=(select auth.uid())
  or (customer_organization_id is not null and exists(
   select 1 from public.krim_organization_members m
   where m.organization_id=customer_organization_id and m.user_id=(select auth.uid()) and m.status='active'
  ))
  or exists(select 1 from public.krim_organization_members m
   where m.user_id=(select auth.uid()) and m.status='active'
    and private.krim_has_permission((select auth.uid()),m.organization_id,'finance.view'))
 );
create table if not exists public.krim_refund_request_events (
 id bigint generated always as identity primary key,
 refund_request_id uuid not null references public.krim_refund_requests(id) on delete restrict,
 event_type text not null check(event_type in ('submitted','review_started','approved','rejected','execution_started','processed','failed')),
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 actor_organization_id bigint references public.krim_organizations(id) on delete restrict,
 event_note text not null,
 event_data jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists krim_refund_request_events_request_idx on public.krim_refund_request_events(refund_request_id,created_at);
alter table public.krim_refund_request_events enable row level security;
alter table public.krim_refund_request_events force row level security;
revoke all on public.krim_refund_request_events from public,anon,authenticated;
grant select on public.krim_refund_request_events to authenticated;
drop policy if exists "KRIM refund request events participant read" on public.krim_refund_request_events;
create policy "KRIM refund request events participant read" on public.krim_refund_request_events
 for select to authenticated using (
  exists(select 1 from public.krim_refund_requests r where r.id=refund_request_id and (
   r.customer_user_id=(select auth.uid())
   or (r.customer_organization_id is not null and exists(select 1 from public.krim_organization_members m where m.organization_id=r.customer_organization_id and m.user_id=(select auth.uid()) and m.status='active'))
   or exists(select 1 from public.krim_organization_members m where m.user_id=(select auth.uid()) and m.status='active' and private.krim_has_permission((select auth.uid()),m.organization_id,'finance.view'))
  ))
 );
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
 if v_order.status not in ('paid','partially_refunded') then raise exception 'Only paid payment orders can be submitted for refund';end if;
 if v_order.customer_id<>v_user and not exists(
  select 1 from public.krim_organization_members m where m.organization_id=v_order.customer_organization_id and m.user_id=v_user and m.status='active'
 ) then raise exception 'Payment order does not belong to this customer';end if;
 if v_order.customer_organization_id is not null and not exists(select 1 from public.krim_organization_members m where m.organization_id=v_order.customer_organization_id and m.user_id=v_user and m.status='active') and v_order.customer_id<>v_user then raise exception 'Active customer organization membership required';end if;
 if p_amount_paise>v_order.amount_paise then raise exception 'Refund request cannot exceed the original payment amount';end if;
 select * into v_existing from public.krim_refund_requests where payment_order_id=p_payment_order_id;
 if found then
  if v_existing.customer_user_id=v_user and v_existing.idempotency_key=p_idempotency_key then return v_existing.id; end if;
  raise exception 'A refund request already exists for this payment order; contact finance for an update';
 end if;
 select id into v_id from public.krim_refund_requests where idempotency_key=p_idempotency_key;
 if v_id is not null then raise exception 'Idempotency key has already been used';end if;
 insert into public.krim_refund_requests(payment_order_id,customer_organization_id,customer_user_id,amount_paise,reason,idempotency_key)
 values(p_payment_order_id,v_order.customer_organization_id,v_user,p_amount_paise,left(trim(p_reason),4000),p_idempotency_key)
 returning id into v_id;
 insert into public.krim_refund_request_events(refund_request_id,event_type,actor_user_id,actor_organization_id,event_note,event_data)
 values(v_id,'submitted',v_user,v_order.customer_organization_id,'Customer submitted a refund request.',jsonb_build_object('payment_order_id',p_payment_order_id,'amount_paise',p_amount_paise));
 return v_id;
end;$function$;
create or replace function private.krim_refund_request_review(p_refund_request_id uuid,p_decision text,p_note text,p_finance_organization_id bigint)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid();v_request public.krim_refund_requests%rowtype;v_next text;v_event text;
begin
 if v_user is null then raise exception 'Authentication required';end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception 'Multi-factor authentication (AAL2) required';end if;
 if p_decision not in ('approve','reject','start_review') then raise exception 'Unsupported refund review decision';end if;
 if length(trim(coalesce(p_note,'')))<20 then raise exception 'A meaningful review note of at least 20 characters is required';end if;
 if not exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id where m.organization_id=p_finance_organization_id and m.user_id=v_user and m.status='active' and o.status='active' and o.organization_type in ('finance','platform','operations')) then raise exception 'Active finance or platform membership required';end if;
 if not private.krim_has_permission(v_user,p_finance_organization_id,'finance.manage') and not private.krim_has_permission(v_user,p_finance_organization_id,'admin.platform') then raise exception 'finance.manage or admin.platform permission required';end if;
 select * into v_request from public.krim_refund_requests where id=p_refund_request_id for update;
 if not found then raise exception 'Refund request not found';end if;
 if v_request.customer_user_id=v_user then raise exception 'The requester cannot review their own refund request';end if;
 if p_decision='start_review' then
  if v_request.status<>'submitted' then raise exception 'Only submitted requests can enter review';end if;
  v_next:='under_review';v_event:='review_started';
 elsif p_decision='approve' then
  if v_request.status not in ('submitted','under_review') then raise exception 'Request is not eligible for approval';end if;
  v_next:='approved_pending_execution';v_event:='approved';
 else
  if v_request.status not in ('submitted','under_review') then raise exception 'Request is not eligible for rejection';end if;
  v_next:='rejected';v_event:='rejected';
 end if;
 update public.krim_refund_requests set status=v_next,reviewed_by=v_user,reviewer_organization_id=p_finance_organization_id,reviewed_at=now(),review_note=left(trim(p_note),4000),updated_at=now() where id=p_refund_request_id;
 insert into public.krim_refund_request_events(refund_request_id,event_type,actor_user_id,actor_organization_id,event_note,event_data)
 values(p_refund_request_id,v_event,v_user,p_finance_organization_id,left(trim(p_note),4000),jsonb_build_object('from_status',v_request.status,'to_status',v_next));
 return p_refund_request_id;
end;$function$;
revoke all on function private.krim_refund_request_submit(uuid,bigint,text,uuid) from public,anon,authenticated;
revoke all on function private.krim_refund_request_review(uuid,text,text,bigint) from public,anon,authenticated;
grant execute on function private.krim_refund_request_submit(uuid,bigint,text,uuid) to authenticated;
grant execute on function private.krim_refund_request_review(uuid,text,text,bigint) to authenticated;
create or replace function public.krim_refund_request_submit(p_payment_order_id uuid,p_amount_paise bigint,p_reason text,p_idempotency_key uuid)
returns uuid language sql security invoker set search_path=public,pg_catalog as $function$
 select private.krim_refund_request_submit(p_payment_order_id,p_amount_paise,p_reason,p_idempotency_key);
$function$;
create or replace function public.krim_refund_request_review(p_refund_request_id uuid,p_decision text,p_note text,p_finance_organization_id bigint)
returns uuid language sql security invoker set search_path=public,pg_catalog as $function$
 select private.krim_refund_request_review(p_refund_request_id,p_decision,p_note,p_finance_organization_id);
$function$;
revoke all on function public.krim_refund_request_submit(uuid,bigint,text,uuid) from public,anon;
revoke all on function public.krim_refund_request_review(uuid,text,text,bigint) from public,anon;
grant execute on function public.krim_refund_request_submit(uuid,bigint,text,uuid) to authenticated;
grant execute on function public.krim_refund_request_review(uuid,text,text,bigint) to authenticated;
