create table public.krim_shipment_return_receipts (
 id uuid primary key default gen_random_uuid(),
 return_id uuid not null unique references public.krim_shipment_returns(id) on delete restrict,
 organization_id bigint not null,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 received_by uuid not null references auth.users(id),
 idempotency_key uuid not null,
 received_at timestamptz not null default now(),
 unique(organization_id,idempotency_key)
);
create table public.krim_shipment_return_receipt_items (
 id uuid primary key default gen_random_uuid(),
 receipt_id uuid not null references public.krim_shipment_return_receipts(id) on delete restrict,
 return_id uuid not null references public.krim_shipment_returns(id) on delete restrict,
 manifest_index integer not null check(manifest_index between 0 and 99),
 inventory_id uuid not null references public.krim_warehouse_inventory(id) on delete restrict,
 sku text not null,
 source_lot_code text,
 return_lot_code text not null,
 quantity numeric not null check(quantity>0 and quantity<>'NaN'::numeric and quantity<>'Infinity'::numeric and quantity<>'-Infinity'::numeric),
 unit_code text not null,
 item_description text not null,
 unique(receipt_id,manifest_index),
 unique(inventory_id)
);
create table public.krim_shipment_return_quality_reviews (
 id uuid primary key default gen_random_uuid(),
 receipt_id uuid not null unique references public.krim_shipment_return_receipts(id) on delete restrict,
 return_id uuid not null references public.krim_shipment_returns(id) on delete restrict,
 organization_id bigint not null,
 facility_id uuid not null references public.krim_warehouse_facilities(id) on delete restrict,
 reviewer_user_id uuid not null references auth.users(id),
 decision text not null check(decision in ('released','hold','rejected')),
 reason text not null check(length(btrim(reason)) between 5 and 1000),
 evidence_path text not null,
 idempotency_key uuid not null,
 created_at timestamptz not null default now(),
 unique(organization_id,idempotency_key)
);
alter table public.krim_shipment_return_receipts enable row level security;
alter table public.krim_shipment_return_receipt_items enable row level security;
alter table public.krim_shipment_return_quality_reviews enable row level security;
revoke all on public.krim_shipment_return_receipts,public.krim_shipment_return_receipt_items,public.krim_shipment_return_quality_reviews from public,anon,authenticated,service_role;
grant select on public.krim_shipment_return_receipts,public.krim_shipment_return_receipt_items,public.krim_shipment_return_quality_reviews to authenticated;
create policy krim_return_receipts_party_read on public.krim_shipment_return_receipts for select to authenticated
using(private.krim_has_permission((select auth.uid()),organization_id,'shipment.view'));
create policy krim_return_receipt_items_party_read on public.krim_shipment_return_receipt_items for select to authenticated
using(exists(select 1 from public.krim_shipment_return_receipts r where r.id=receipt_id and private.krim_has_permission((select auth.uid()),r.organization_id,'shipment.view')));
create policy krim_return_quality_party_read on public.krim_shipment_return_quality_reviews for select to authenticated
using(private.krim_has_permission((select auth.uid()),organization_id,'shipment.view'));

create function public.krim_receive_authorized_shipment_return(
 p_return_id uuid,p_facility_id uuid,p_received_items jsonb,p_idempotency_key uuid,p_notes text default ''
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_return public.krim_shipment_returns%rowtype;
 v_fac public.krim_warehouse_facilities%rowtype; v_receipt public.krim_shipment_return_receipts%rowtype;
 v_item jsonb; v_manifest jsonb; v_idx integer; v_qty numeric; v_sku text; v_unit text; v_desc text; v_lot text;
 v_result jsonb; v_inventory_id uuid; v_return_lot text; v_line_count integer:=0; v_existing public.krim_shipment_return_receipts%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_return_id is null or p_facility_id is null or p_idempotency_key is null or jsonb_typeof(p_received_items)<>'array' or jsonb_array_length(p_received_items)<1 or jsonb_array_length(p_received_items)>100 then
  raise exception 'Return, approved facility, 1–100 received items and idempotency key are required' using errcode='22023';
 end if;
 select * into v_return from public.krim_shipment_returns where id=p_return_id for update;
 if not found then raise exception 'Return not found' using errcode='P0002'; end if;
 if v_return.status<>'authorized' then raise exception 'Only partner-authorised returns can be physically received' using errcode='23514'; end if;
 if not private.krim_has_permission(v_user,v_return.partner_organization_id,'partner.manage') then raise exception 'Partner warehouse management permission required' using errcode='42501'; end if;
 if not private.krim_warehouse_is_operator(v_user,v_return.partner_organization_id,p_facility_id) then raise exception 'Authorised operator at destination facility required' using errcode='42501'; end if;
 select * into v_fac from public.krim_warehouse_facilities where id=p_facility_id and organization_id=v_return.partner_organization_id and status='active' and review_status='approved';
 if not found then raise exception 'Facility must be active and independently approved' using errcode='23514'; end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_return_receipt:'||v_return.partner_organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_existing from public.krim_shipment_return_receipts where return_id=p_return_id for update;
 if found then
  if v_existing.idempotency_key<>p_idempotency_key or v_existing.facility_id<>p_facility_id or v_existing.received_by<>v_user then raise exception 'Return already received; conflicting receipt replay rejected' using errcode='23505'; end if;
  return jsonb_build_object('replayed',true,'receipt',to_jsonb(v_existing));
 end if;
 if exists(select 1 from public.krim_shipment_return_receipts where organization_id=v_return.partner_organization_id and idempotency_key=p_idempotency_key) then raise exception 'Receipt idempotency key already used' using errcode='23505'; end if;
 v_manifest:=v_return.item_manifest;
 if jsonb_array_length(p_received_items)<>jsonb_array_length(v_manifest) then raise exception 'Every authorised manifest line must be physically reconciled exactly once' using errcode='23514'; end if;
 insert into public.krim_shipment_return_receipts(return_id,organization_id,facility_id,received_by,idempotency_key)
 values(p_return_id,v_return.partner_organization_id,p_facility_id,v_user,p_idempotency_key) returning * into v_receipt;
 for v_item in select value from jsonb_array_elements(p_received_items) loop
  if coalesce(v_item->>'manifest_index','') !~ '^[0-9]+$' then raise exception 'Each received item needs a valid manifest_index' using errcode='22023'; end if;
  v_idx:=(v_item->>'manifest_index')::integer;
  if v_idx<0 or v_idx>=jsonb_array_length(v_manifest) or exists(select 1 from public.krim_shipment_return_receipt_items where receipt_id=v_receipt.id and manifest_index=v_idx) then raise exception 'Invalid or duplicate manifest index' using errcode='23514'; end if;
  v_qty:=(v_item->>'quantity')::numeric; v_sku:=btrim(coalesce(v_item->>'sku','')); v_unit:=btrim(coalesce(v_item->>'unit',''));
  v_desc:=btrim(coalesce(v_item->>'description','')); v_lot:=nullif(btrim(coalesce(v_item->>'source_lot_code','')),'');
  if v_qty<=0 or v_qty='NaN'::numeric or v_qty='Infinity'::numeric or v_qty='-Infinity'::numeric or v_sku='' or length(v_sku)>120 or v_unit='' or v_desc='' then raise exception 'SKU, description, unit and finite positive quantity are required' using errcode='22023'; end if;
  if v_qty<>(v_manifest->v_idx->>'quantity')::numeric or lower(v_unit)<>lower(v_manifest->v_idx->>'unit') or lower(v_desc)<>lower(v_manifest->v_idx->>'description') then raise exception 'Received item quantity, unit and description must exactly match its authorised manifest line' using errcode='23514'; end if;
  v_return_lot:='RET-'||replace(p_return_id::text,'-','')||'-'||v_idx::text;
  v_result:=public.krim_warehouse_record_movement(v_return.partner_organization_id,p_facility_id,v_sku,v_qty,'receipt',
   (substr(md5(p_idempotency_key::text||':'||v_idx::text),1,8)||'-'||substr(md5(p_idempotency_key::text||':'||v_idx::text),9,4)||'-4'||substr(md5(p_idempotency_key::text||':'||v_idx::text),14,3)||'-a'||substr(md5(p_idempotency_key::text||':'||v_idx::text),18,3)||'-'||substr(md5(p_idempotency_key::text||':'||v_idx::text),21,12))::uuid,
   v_desc,v_return_lot,v_unit,null,'hold','shipment_return',p_return_id::text,coalesce(p_notes,'Physical return receipt; inspection hold'));
  v_inventory_id:=(v_result->'inventory'->>'id')::uuid;
  insert into public.krim_shipment_return_receipt_items(receipt_id,return_id,manifest_index,inventory_id,sku,source_lot_code,return_lot_code,quantity,unit_code,item_description)
  values(v_receipt.id,p_return_id,v_idx,v_inventory_id,v_sku,v_lot,v_return_lot,v_qty,v_unit,v_desc);
  v_line_count:=v_line_count+1;
 end loop;
 update public.krim_shipment_returns set status='inspection_hold',updated_at=now() where id=p_return_id returning * into v_return;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,v_return.partner_organization_id,'shipment.return.physically_received','shipment_return',p_return_id::text,'rpc',
  jsonb_build_object('receipt_id',v_receipt.id,'facility_id',p_facility_id,'item_count',v_line_count,'quality_status','hold'));
 return jsonb_build_object('replayed',false,'receipt',to_jsonb(v_receipt),'items',(
  select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.krim_shipment_return_receipt_items i where i.receipt_id=v_receipt.id));
end
$fn$;

create function public.krim_review_shipment_return_quality(
 p_receipt_id uuid,p_decision text,p_reason text,p_evidence_path text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_receipt public.krim_shipment_return_receipts%rowtype;
 v_return public.krim_shipment_returns%rowtype; v_review public.krim_shipment_return_quality_reviews%rowtype;
 v_path text:=btrim(coalesce(p_evidence_path,'')); v_reason text:=btrim(coalesce(p_reason,''));
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_receipt_id is null or p_idempotency_key is null or p_decision not in ('released','hold','rejected') or length(v_reason)<5 or length(v_reason)>1000 or v_path='' then
  raise exception 'Receipt, decision, reason, private inspection evidence and idempotency key are required' using errcode='22023';
 end if;
 select * into v_receipt from public.krim_shipment_return_receipts where id=p_receipt_id for update;
 if not found then raise exception 'Return receipt not found' using errcode='P0002'; end if;
 select * into v_return from public.krim_shipment_returns where id=v_receipt.return_id for update;
 if v_return.status<>'inspection_hold' then raise exception 'Return must remain on inspection hold before quality review' using errcode='23514'; end if;
 if not private.krim_warehouse_is_operator(v_user,v_receipt.organization_id,v_receipt.facility_id) then raise exception 'Authorised facility quality reviewer required' using errcode='42501'; end if;
 if v_user=v_receipt.received_by then raise exception 'Independent quality reviewer cannot be the receiving operator' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_return_qc:'||v_receipt.organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_review from public.krim_shipment_return_quality_reviews where receipt_id=p_receipt_id for update;
 if found then
  if v_review.reviewer_user_id<>v_user or v_review.decision<>p_decision or v_review.reason<>v_reason or v_review.evidence_path<>v_path or v_review.idempotency_key<>p_idempotency_key then raise exception 'Final return quality review already exists; conflicting replay rejected' using errcode='23505'; end if;
  return jsonb_build_object('replayed',true,'review',to_jsonb(v_review));
 end if;
 if exists(select 1 from public.krim_shipment_return_quality_reviews where organization_id=v_receipt.organization_id and idempotency_key=p_idempotency_key) then raise exception 'Quality idempotency key already used' using errcode='23505'; end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='krim-warehouse-evidence' and o.name=v_path and o.owner=v_user
  and split_part(o.name,'/',1)=v_receipt.organization_id::text and split_part(o.name,'/',2)=v_user::text
  and cardinality(string_to_array(o.name,'/'))=3
  and coalesce(o.metadata->>'mimetype','') in ('image/jpeg','image/png','application/pdf')
  and coalesce(o.metadata->>'size','') ~ '^[0-9]+$' and (o.metadata->>'size')::bigint between 1 and 10485760) then
  raise exception 'Evidence must be a reviewer-owned private image or PDF under the authorised warehouse evidence path, maximum 10 MB' using errcode='23514';
 end if;
 insert into public.krim_shipment_return_quality_reviews(receipt_id,return_id,organization_id,facility_id,reviewer_user_id,decision,reason,evidence_path,idempotency_key)
 values(p_receipt_id,v_return.id,v_receipt.organization_id,v_receipt.facility_id,v_user,p_decision,v_reason,v_path,p_idempotency_key) returning * into v_review;
 update public.krim_warehouse_inventory i set quality_status=p_decision,updated_at=now()
 from public.krim_shipment_return_receipt_items ri where ri.receipt_id=p_receipt_id and ri.inventory_id=i.id and i.quality_status='hold';
 if not found then raise exception 'No held return inventory found; no quality status changed' using errcode='23514'; end if;
 update public.krim_shipment_returns set status=p_decision,updated_at=now() where id=v_return.id;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,v_receipt.organization_id,'shipment.return.quality_reviewed','shipment_return',v_return.id::text,'rpc',
  jsonb_build_object('receipt_id',p_receipt_id,'decision',p_decision,'reason',v_reason,'evidence_path',v_path,
   'inventory_ids',(select jsonb_agg(inventory_id) from public.krim_shipment_return_receipt_items where receipt_id=p_receipt_id)));
 return jsonb_build_object('replayed',false,'review',to_jsonb(v_review),'return_status',p_decision);
end
$fn$;
revoke all on function public.krim_receive_authorized_shipment_return(uuid,uuid,jsonb,uuid,text) from public,anon;
revoke all on function public.krim_review_shipment_return_quality(uuid,text,text,text,uuid) from public,anon;
grant execute on function public.krim_receive_authorized_shipment_return(uuid,uuid,jsonb,uuid,text) to authenticated;
grant execute on function public.krim_review_shipment_return_quality(uuid,text,text,text,uuid) to authenticated;