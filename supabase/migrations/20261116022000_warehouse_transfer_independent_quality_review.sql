-- Independent inspection and release gate for received inter-facility transfers.
alter table public.krim_warehouse_transfers
  add column if not exists quality_status text not null default 'pending'
    check (quality_status in ('pending','released','hold','rejected')),
  add column if not exists quality_reviewed_by uuid references auth.users(id),
  add column if not exists quality_reviewed_at timestamptz;

create table if not exists public.krim_warehouse_transfer_quality_reviews (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null unique references public.krim_warehouse_transfers(id) on delete restrict,
  organization_id bigint not null references public.krim_organizations(id) on delete restrict,
  facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
  reviewer_user_id uuid not null references auth.users(id),
  decision text not null check (decision in ('released','hold','rejected')),
  reason text not null check (length(btrim(reason)) between 5 and 1000),
  evidence_bucket text not null default 'krim-warehouse-evidence'
    check (evidence_bucket='krim-warehouse-evidence'),
  evidence_path text not null,
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  unique (organization_id,idempotency_key)
);
alter table public.krim_warehouse_transfer_quality_reviews enable row level security;
revoke all on public.krim_warehouse_transfer_quality_reviews from public,anon,authenticated,service_role;
grant select on public.krim_warehouse_transfer_quality_reviews to authenticated;
create policy krim_warehouse_transfer_quality_reviews_operator_read
on public.krim_warehouse_transfer_quality_reviews for select to authenticated
using (private.krim_warehouse_is_operator((select auth.uid()),organization_id,facility_id));

create or replace function public.krim_warehouse_review_transfer_quality(
  p_transfer_id uuid,p_decision text,p_reason text,p_evidence_path text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid:=auth.uid(); v_transfer public.krim_warehouse_transfers%rowtype;
 v_inventory public.krim_warehouse_inventory%rowtype;
 v_review public.krim_warehouse_transfer_quality_reviews%rowtype;
 v_path text:=btrim(coalesce(p_evidence_path,'')); v_reason text:=btrim(coalesce(p_reason,''));
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_transfer_id is null or p_idempotency_key is null then raise exception 'Transfer and idempotency key are required' using errcode='22023'; end if;
 if p_decision not in ('released','hold','rejected') then raise exception 'Unsupported quality decision' using errcode='22023'; end if;
 if length(v_reason)<5 or length(v_reason)>1000 then raise exception 'Quality review reason must contain 5–1,000 characters' using errcode='22023'; end if;
 if v_path='' or length(v_path)>1024 then raise exception 'A private inspection evidence path is required' using errcode='22023'; end if;
 select * into v_transfer from public.krim_warehouse_transfers where id=p_transfer_id for update;
 if not found then raise exception 'Transfer not found' using errcode='P0002'; end if;
 if v_transfer.status<>'received' or v_transfer.destination_inventory_id is null then raise exception 'Only received transfers can undergo quality review' using errcode='23514'; end if;
 if not private.krim_warehouse_is_operator(v_user,v_transfer.organization_id,v_transfer.destination_facility_id) then raise exception 'Verified destination warehouse operator access required' using errcode='42501'; end if;
 if v_user in (v_transfer.dispatched_by,v_transfer.received_by) then raise exception 'Independent reviewer must differ from transfer dispatcher and receiver' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_wh_transfer_quality:'||v_transfer.organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_review from public.krim_warehouse_transfer_quality_reviews where transfer_id=p_transfer_id for update;
 if found then
  if v_review.reviewer_user_id<>v_user or v_review.decision<>p_decision or v_review.reason<>v_reason
   or v_review.evidence_path<>v_path or v_review.idempotency_key<>p_idempotency_key then
   raise exception 'Transfer already has a final quality decision; conflicting review replay rejected' using errcode='23505';
  end if;
  return jsonb_build_object('replayed',true,'review',to_jsonb(v_review));
 end if;
 if exists(select 1 from public.krim_warehouse_transfer_quality_reviews where organization_id=v_transfer.organization_id and idempotency_key=p_idempotency_key) then
  raise exception 'Quality review idempotency key already used' using errcode='23505';
 end if;
 if not exists (
  select 1 from storage.objects o where o.bucket_id='krim-warehouse-evidence' and o.name=v_path and o.owner=v_user
   and split_part(o.name,'/',1)=v_transfer.organization_id::text and split_part(o.name,'/',2)=v_user::text
   and cardinality(string_to_array(o.name,'/'))=3
   and coalesce(o.metadata->>'mimetype','') in ('image/jpeg','image/png','application/pdf')
   and coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
   and (o.metadata->>'size')::bigint between 1 and 10485760
 ) then raise exception 'Inspection evidence must be a private, reviewer-owned image or PDF in the authorised warehouse evidence path, up to 10 MB' using errcode='23514'; end if;
 select * into v_inventory from public.krim_warehouse_inventory
  where id=v_transfer.destination_inventory_id and organization_id=v_transfer.organization_id
   and facility_id=v_transfer.destination_facility_id for update;
 if not found then raise exception 'Destination inventory balance not found' using errcode='P0002'; end if;
 if v_inventory.quality_status<>'hold' then raise exception 'Destination inventory is not on quality hold; refusing to overwrite another quality decision' using errcode='23514'; end if;
 insert into public.krim_warehouse_transfer_quality_reviews(transfer_id,organization_id,facility_id,reviewer_user_id,decision,reason,evidence_path,idempotency_key)
 values(p_transfer_id,v_transfer.organization_id,v_transfer.destination_facility_id,v_user,p_decision,v_reason,v_path,p_idempotency_key)
 returning * into v_review;
 update public.krim_warehouse_inventory set quality_status=p_decision,updated_at=now()
  where id=v_inventory.id returning * into v_inventory;
 update public.krim_warehouse_transfers set quality_status=p_decision,quality_reviewed_by=v_user,quality_reviewed_at=now()
  where id=p_transfer_id returning * into v_transfer;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,v_transfer.organization_id,'warehouse.transfer.quality_reviewed','warehouse_transfer',p_transfer_id::text,'rpc',
  jsonb_build_object('destination_facility_id',v_transfer.destination_facility_id,'destination_inventory_id',v_inventory.id,
   'decision',p_decision,'reason',v_reason,'evidence_bucket','krim-warehouse-evidence','evidence_path',v_path),
  jsonb_build_object('quality_status','pending'),jsonb_build_object('quality_status',p_decision,'reviewed_by',v_user));
 return jsonb_build_object('replayed',false,'transfer_id',p_transfer_id,'inventory_id',v_inventory.id,
  'quality_status',v_inventory.quality_status,'review',to_jsonb(v_review));
end; $$;
revoke all on function public.krim_warehouse_review_transfer_quality(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.krim_warehouse_review_transfer_quality(uuid,text,text,text,uuid) to authenticated;
