-- Applied to KRIM production project ebltviniygljwwseplph as 20261104111128.
-- End-to-end warehouse task runtime, event audit trail, and private evidence.
create table if not exists public.krim_warehouse_tasks (
 id uuid primary key default gen_random_uuid(), organization_id bigint not null references public.krim_organizations(id),
 facility_id uuid not null references public.krim_warehouse_facilities(id),
 task_type text not null check(task_type in ('inbound_receiving','goods_receipt','putaway_storage','picking_packing','dispatch_handover','damage_exception','cycle_count')),
 reference_code text not null, sku text, item_description text, lot_code text, quantity numeric, unit_code text not null default 'unit',
 source_location text, destination_location text, quality_status text not null default 'pending' check(quality_status in ('pending','released','hold','rejected')),
 severity text not null default 'normal' check(severity in ('normal','low','medium','high','critical')),
 status text not null default 'open' check(status in ('open','in_progress','on_hold','completed','cancelled')),
 notes text not null default '', metadata jsonb not null default '{}'::jsonb, idempotency_key uuid not null,
 created_by uuid not null references auth.users(id), completed_by uuid references auth.users(id), completed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(organization_id,idempotency_key), check(quantity is null or (quantity>0 and quantity<'Infinity'::numeric and quantity<>'NaN'::numeric)),
 check(length(btrim(reference_code)) between 1 and 120)
);
create index if not exists krim_wh_tasks_org_status_idx on public.krim_warehouse_tasks(organization_id,status,created_at desc);
create index if not exists krim_wh_tasks_ref_idx on public.krim_warehouse_tasks(organization_id,reference_code,task_type);
create table if not exists public.krim_warehouse_task_events (
 id uuid primary key default gen_random_uuid(), task_id uuid not null references public.krim_warehouse_tasks(id),
 organization_id bigint not null references public.krim_organizations(id), facility_id uuid not null references public.krim_warehouse_facilities(id),
 event_type text not null, previous_status text, new_status text, metadata jsonb not null default '{}'::jsonb,
 actor_user_id uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists krim_wh_task_events_task_idx on public.krim_warehouse_task_events(task_id,created_at desc);
create table if not exists public.krim_warehouse_evidence (
 id uuid primary key default gen_random_uuid(), task_id uuid not null references public.krim_warehouse_tasks(id),
 organization_id bigint not null references public.krim_organizations(id), facility_id uuid not null references public.krim_warehouse_facilities(id),
 bucket_id text not null default 'krim-warehouse-evidence', storage_path text not null unique,
 evidence_type text not null check(evidence_type in ('arrival_photo','seal_record','damage_photo','count_sheet','inspection_report','dispatch_proof','other')),
 description text not null default '', captured_at timestamptz, created_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists krim_wh_evidence_task_idx on public.krim_warehouse_evidence(task_id,created_at desc);
alter table public.krim_warehouse_tasks enable row level security;
alter table public.krim_warehouse_task_events enable row level security;
alter table public.krim_warehouse_evidence enable row level security;
create or replace function private.krim_warehouse_is_operator(p_user_id uuid,p_organization_id bigint,p_facility_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 join public.krim_warehouse_facilities f on f.organization_id=o.id where o.id=p_organization_id and f.id=p_facility_id
 and p_user_id is not null and m.user_id=p_user_id and m.status='active' and o.status='active'
 and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved')
 and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
 and f.status='active' and f.review_status='approved' and private.krim_has_permission(p_user_id,p_organization_id,'partner.manage'));
$$;
revoke all on function private.krim_warehouse_is_operator(uuid,bigint,uuid) from public,anon,authenticated;
create policy krim_wh_tasks_member_read on public.krim_warehouse_tasks for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_tasks.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_tasks.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
 and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified')
 and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable') and f.status='active' and f.review_status='approved'));
create policy krim_wh_task_events_member_read on public.krim_warehouse_task_events for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_task_events.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_task_events.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
 and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified')
 and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable') and f.status='active' and f.review_status='approved'));
create policy krim_wh_evidence_member_read on public.krim_warehouse_evidence for select to authenticated using (
 exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id join public.krim_warehouse_facilities f on f.id=krim_warehouse_evidence.facility_id and f.organization_id=o.id
 where m.organization_id=krim_warehouse_evidence.organization_id and m.user_id=(select auth.uid()) and m.status='active' and o.status='active'
 and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified')
 and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable') and f.status='active' and f.review_status='approved'));
revoke all on public.krim_warehouse_tasks,public.krim_warehouse_task_events,public.krim_warehouse_evidence from anon,authenticated;
grant select on public.krim_warehouse_tasks,public.krim_warehouse_task_events,public.krim_warehouse_evidence to authenticated;

-- RPC definitions are intentionally SECURITY DEFINER because they write multiple
-- related records atomically; each verifies auth.uid(), active membership, verified
-- registered-business status, approved facility, and partner.manage permission.
-- See function definitions in the live migration 20261104111128.
create or replace function public.krim_warehouse_create_task(p_organization_id bigint,p_facility_id uuid,p_task_type text,p_reference_code text,p_sku text,p_item_description text,p_lot_code text,p_quantity numeric,p_unit_code text,p_source_location text,p_destination_location text,p_quality_status text,p_severity text,p_notes text,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_task public.krim_warehouse_tasks%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if not private.krim_warehouse_is_operator(v_user,p_organization_id,p_facility_id) then raise exception 'Verified warehouse facility access and partner.manage permission required' using errcode='42501';end if;
 if p_task_type not in ('inbound_receiving','goods_receipt','putaway_storage','picking_packing','dispatch_handover','damage_exception','cycle_count') then raise exception 'Unsupported warehouse task type' using errcode='22023';end if;
 if nullif(btrim(p_reference_code),'') is null or length(btrim(p_reference_code))>120 or p_idempotency_key is null then raise exception 'Valid operation reference and idempotency key are required' using errcode='22023';end if;
 if p_task_type in ('goods_receipt','putaway_storage','picking_packing') and (nullif(btrim(p_sku),'') is null or p_quantity is null or p_quantity<=0 or p_quantity>='Infinity'::numeric or p_quantity='NaN'::numeric) then raise exception 'SKU and finite positive quantity are required' using errcode='22023';end if;
 if coalesce(p_quality_status,'pending') not in ('pending','released','hold','rejected') or coalesce(p_severity,'normal') not in ('normal','low','medium','high','critical') then raise exception 'Invalid quality or severity status' using errcode='22023';end if;
 select * into v_task from public.krim_warehouse_tasks where organization_id=p_organization_id and idempotency_key=p_idempotency_key;
 if found then return jsonb_build_object('replayed',true,'task',to_jsonb(v_task));end if;
 if p_task_type='inbound_receiving' then
  insert into public.krim_warehouse_receipts(organization_id,facility_id,receipt_reference,status,notes) values(p_organization_id,p_facility_id,btrim(p_reference_code),'expected',coalesce(p_notes,''));
 elsif p_task_type='goods_receipt' and not exists(select 1 from public.krim_warehouse_receipts r where r.organization_id=p_organization_id and r.facility_id=p_facility_id and r.receipt_reference=btrim(p_reference_code) and r.status in ('received','quality_hold')) then
  raise exception 'Complete inbound receiving and quality check before goods receipt' using errcode='23514';
 elsif p_task_type='putaway_storage' then
  if nullif(btrim(p_destination_location),'') is null or not exists(select 1 from public.krim_warehouse_inventory i where i.organization_id=p_organization_id and i.facility_id=p_facility_id and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'') and i.quantity=p_quantity) then raise exception 'Put-away requires the full matching SKU/lot balance and destination location' using errcode='23514';end if;
 elsif p_task_type='picking_packing' and not exists(select 1 from public.krim_warehouse_inventory i where i.organization_id=p_organization_id and i.facility_id=p_facility_id and lower(i.sku)=lower(btrim(p_sku)) and i.lot_code is not distinct from nullif(btrim(p_lot_code),'') and i.quantity>=p_quantity and i.quality_status='released') then
  raise exception 'Insufficient released inventory for this pick' using errcode='23514';
 end if;
 insert into public.krim_warehouse_tasks(organization_id,facility_id,task_type,reference_code,sku,item_description,lot_code,quantity,unit_code,source_location,destination_location,quality_status,severity,notes,idempotency_key,created_by)
 values(p_organization_id,p_facility_id,p_task_type,btrim(p_reference_code),nullif(btrim(p_sku),''),nullif(btrim(p_item_description),''),nullif(btrim(p_lot_code),''),p_quantity,coalesce(nullif(btrim(p_unit_code),''),'unit'),nullif(btrim(p_source_location),''),nullif(btrim(p_destination_location),''),coalesce(p_quality_status,'pending'),coalesce(p_severity,'normal'),left(coalesce(p_notes,''),4000),p_idempotency_key,v_user) returning * into v_task;
 insert into public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,new_status,metadata,actor_user_id) values(v_task.id,p_organization_id,p_facility_id,'task.created','open',jsonb_build_object('task_type',p_task_type,'reference_code',p_reference_code),v_user);
 return jsonb_build_object('replayed',false,'task',to_jsonb(v_task));
end;$$;

create or replace function public.krim_warehouse_transition_task(p_task_id uuid,p_new_status text,p_idempotency_key uuid,p_notes text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_task public.krim_warehouse_tasks%rowtype;v_movement jsonb;v_old text;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 if p_task_id is null or p_idempotency_key is null then raise exception 'Task and idempotency keys are required' using errcode='22023';end if;
 select * into v_task from public.krim_warehouse_tasks where id=p_task_id for update;
 if not found then raise exception 'Warehouse task not found' using errcode='P0002';end if;
 if not private.krim_warehouse_is_operator(v_user,v_task.organization_id,v_task.facility_id) then raise exception 'Warehouse operator authorization required' using errcode='42501';end if;
 if exists(select 1 from public.krim_warehouse_task_events e where e.task_id=v_task.id and e.metadata->>'transition_key'=p_idempotency_key::text) then return jsonb_build_object('replayed',true,'task',to_jsonb(v_task));end if;
 if p_new_status not in ('in_progress','on_hold','completed','cancelled') or v_task.status in ('completed','cancelled') then raise exception 'Unsupported transition or terminal task' using errcode='55000';end if;
 v_old:=v_task.status;
 if p_new_status='completed' and v_old<>'in_progress' then raise exception 'Move task to in progress before completion' using errcode='55000';end if;
 if p_new_status='in_progress' and v_old not in ('open','on_hold') then raise exception 'Invalid transition to in progress' using errcode='55000';end if;
 if p_new_status='on_hold' and v_old not in ('open','in_progress') then raise exception 'Invalid transition to hold' using errcode='55000';end if;
 if p_new_status='completed' then
  if v_task.task_type='inbound_receiving' then
   update public.krim_warehouse_receipts set status=case when v_task.quality_status in ('hold','rejected') then 'quality_hold' else 'received' end where organization_id=v_task.organization_id and facility_id=v_task.facility_id and receipt_reference=v_task.reference_code and status='expected';
   if not found then raise exception 'Expected receipt record not found' using errcode='23514';end if;
  elsif v_task.task_type='goods_receipt' then
   select public.krim_warehouse_record_movement(v_task.organization_id,v_task.facility_id,v_task.sku,v_task.quantity,'receipt',p_idempotency_key,coalesce(v_task.item_description,v_task.sku),v_task.lot_code,v_task.unit_code,v_task.destination_location,v_task.quality_status,'warehouse_task',v_task.id::text,coalesce(p_notes,v_task.notes)) into v_movement;
  elsif v_task.task_type='putaway_storage' then
   perform 1 from public.krim_warehouse_inventory where organization_id=v_task.organization_id and facility_id=v_task.facility_id and lower(sku)=lower(v_task.sku) and lot_code is not distinct from v_task.lot_code and quantity=v_task.quantity for update;
   if not found then raise exception 'Matching full inventory lot was not found for put-away' using errcode='23514';end if;
   update public.krim_warehouse_inventory set storage_location=v_task.destination_location,updated_at=now() where organization_id=v_task.organization_id and facility_id=v_task.facility_id and lower(sku)=lower(v_task.sku) and lot_code is not distinct from v_task.lot_code and quantity=v_task.quantity;
   update public.krim_warehouse_receipts set status='put_away' where organization_id=v_task.organization_id and facility_id=v_task.facility_id and receipt_reference=v_task.reference_code and status in ('received','quality_hold');
  elsif v_task.task_type='picking_packing' then
   select public.krim_warehouse_record_movement(v_task.organization_id,v_task.facility_id,v_task.sku,-v_task.quantity,'pick',p_idempotency_key,coalesce(v_task.item_description,v_task.sku),v_task.lot_code,v_task.unit_code,v_task.source_location,'released','warehouse_task',v_task.id::text,coalesce(p_notes,v_task.notes)) into v_movement;
  elsif v_task.task_type='dispatch_handover' and not exists(select 1 from public.krim_warehouse_tasks t where t.organization_id=v_task.organization_id and t.facility_id=v_task.facility_id and t.reference_code=v_task.reference_code and t.task_type='picking_packing' and t.status='completed') then
   raise exception 'A completed pick/pack task for this reference is required before dispatch handover' using errcode='23514';
  elsif v_task.task_type='damage_exception' then
   update public.krim_warehouse_inventory set quality_status='hold',updated_at=now() where organization_id=v_task.organization_id and facility_id=v_task.facility_id and lower(sku)=lower(coalesce(v_task.sku,'')) and (v_task.lot_code is null or lot_code=v_task.lot_code);
  end if;
 end if;
 update public.krim_warehouse_tasks set status=p_new_status,updated_at=now(),completed_by=case when p_new_status='completed' then v_user else completed_by end,completed_at=case when p_new_status='completed' then now() else completed_at end,metadata=metadata||jsonb_build_object('last_transition_key',p_idempotency_key::text,'last_transition_notes',left(coalesce(p_notes,''),1000)) where id=v_task.id returning * into v_task;
 insert into public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,previous_status,new_status,metadata,actor_user_id) values(v_task.id,v_task.organization_id,v_task.facility_id,'task.status_changed',v_old,p_new_status,jsonb_build_object('transition_key',p_idempotency_key::text,'notes',left(coalesce(p_notes,''),1000),'inventory_movement',v_movement),v_user);
 return jsonb_build_object('replayed',false,'task',to_jsonb(v_task),'inventory_movement',v_movement);
end;$$;

create or replace function public.krim_warehouse_list_tasks(p_task_type text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_items jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items from (
 select t.id,t.organization_id,o.legal_name organization_name,t.facility_id,f.facility_code,f.facility_name,t.task_type,t.reference_code,t.sku,t.item_description,t.lot_code,t.quantity,t.unit_code,t.source_location,t.destination_location,t.quality_status,t.severity,t.status,t.notes,t.created_at,t.updated_at,t.completed_at
 from public.krim_warehouse_tasks t join public.krim_organizations o on o.id=t.organization_id join public.krim_warehouse_facilities f on f.id=t.facility_id
 where (p_task_type is null or t.task_type=p_task_type) and private.krim_warehouse_is_operator(v_user,t.organization_id,t.facility_id) order by t.created_at desc limit 250) x;
 return jsonb_build_object('items',v_items);
end;$$;

create or replace function public.krim_warehouse_dashboard()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_orgs bigint[];v_result jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select coalesce(array_agg(distinct o.id),'{}'::bigint[]) into v_orgs from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 where m.user_id=v_user and m.status='active' and o.status='active' and o.partner_account_mode='registered_business' and o.partner_verification_status in ('verified','approved')
 and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%') and private.krim_has_permission(v_user,o.id,'partner.manage');
 select jsonb_build_object('open_tasks',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.status in ('open','in_progress','on_hold')),
 'completed_today',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.status='completed' and t.completed_at>=date_trunc('day',now())),
 'active_facilities',(select count(*) from public.krim_warehouse_facilities f where f.organization_id=any(v_orgs) and f.status='active' and f.review_status='approved'),
 'inventory_skus',(select count(*) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs)),
 'inventory_units',(select coalesce(sum(i.quantity),0) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs)),
 'pending_quality',(select count(*) from public.krim_warehouse_inventory i where i.organization_id=any(v_orgs) and i.quality_status in ('pending','hold')),
 'recent_tasks',(select count(*) from public.krim_warehouse_tasks t where t.organization_id=any(v_orgs) and t.created_at>=now()-interval '7 days')) into v_result;
 return coalesce(v_result,'{}'::jsonb);
end;$$;

create or replace function public.krim_warehouse_register_evidence(p_task_id uuid,p_evidence_type text,p_storage_path text,p_description text,p_captured_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_task public.krim_warehouse_tasks%rowtype;v_ev public.krim_warehouse_evidence%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select * into v_task from public.krim_warehouse_tasks where id=p_task_id;
 if not found then raise exception 'Task not found' using errcode='P0002';end if;
 if not private.krim_warehouse_is_operator(v_user,v_task.organization_id,v_task.facility_id) then raise exception 'Warehouse evidence permission denied' using errcode='42501';end if;
 if p_evidence_type not in ('arrival_photo','seal_record','damage_photo','count_sheet','inspection_report','dispatch_proof','other') then raise exception 'Unsupported evidence type' using errcode='22023';end if;
 if p_storage_path is null or split_part(p_storage_path,'/',1)<>v_task.organization_id::text or split_part(p_storage_path,'/',2)<>v_user::text then raise exception 'Evidence path must be under the submitting organisation and user folder' using errcode='42501';end if;
 if not exists(select 1 from storage.objects where bucket_id='krim-warehouse-evidence' and name=p_storage_path) then raise exception 'Uploaded private evidence object not found' using errcode='P0002';end if;
 insert into public.krim_warehouse_evidence(task_id,organization_id,facility_id,storage_path,evidence_type,description,captured_at,created_by) values(v_task.id,v_task.organization_id,v_task.facility_id,p_storage_path,p_evidence_type,left(coalesce(p_description,''),2000),p_captured_at,v_user) returning * into v_ev;
 insert into public.krim_warehouse_task_events(task_id,organization_id,facility_id,event_type,metadata,actor_user_id) values(v_task.id,v_task.organization_id,v_task.facility_id,'task.evidence_added',jsonb_build_object('evidence_id',v_ev.id,'evidence_type',p_evidence_type),v_user);
 return jsonb_build_object('evidence_id',v_ev.id,'task_id',v_task.id,'status','stored_privately');
end;$$;

create or replace function public.krim_warehouse_list_events(p_task_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_items jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items from (
 select e.id,e.task_id,e.event_type,e.previous_status,e.new_status,e.metadata,e.created_at,t.reference_code,t.task_type from public.krim_warehouse_task_events e join public.krim_warehouse_tasks t on t.id=e.task_id
 where (p_task_id is null or e.task_id=p_task_id) and private.krim_warehouse_is_operator(v_user,e.organization_id,e.facility_id) order by e.created_at desc limit 300) x;
 return jsonb_build_object('items',v_items);
end;$$;

create or replace function public.krim_warehouse_list_evidence(p_task_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_items jsonb;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000';end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_items from (
 select e.id,e.task_id,e.evidence_type,e.storage_path,e.description,e.captured_at,e.created_at,t.reference_code,t.task_type from public.krim_warehouse_evidence e join public.krim_warehouse_tasks t on t.id=e.task_id
 where (p_task_id is null or e.task_id=p_task_id) and private.krim_warehouse_is_operator(v_user,e.organization_id,e.facility_id) order by e.created_at desc limit 300) x;
 return jsonb_build_object('items',v_items);
end;$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('krim-warehouse-evidence','krim-warehouse-evidence',false,10485760,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create policy krim_wh_evidence_upload on storage.objects for insert to authenticated with check (
 bucket_id='krim-warehouse-evidence' and (storage.foldername(name))[2]=(select auth.uid())::text
 and case when (storage.foldername(name))[1] ~ '^[0-9]+$' then exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 where o.id=((storage.foldername(name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business'
 and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
 and private.krim_has_permission((select auth.uid()),o.id,'partner.manage')) else false end);
create policy krim_wh_evidence_read on storage.objects for select to authenticated using (
 bucket_id='krim-warehouse-evidence' and case when (storage.foldername(name))[1] ~ '^[0-9]+$' then exists(select 1 from public.krim_organizations o join public.krim_organization_members m on m.organization_id=o.id
 where o.id=((storage.foldername(name))[1])::bigint and m.user_id=(select auth.uid()) and m.status='active' and o.status='active' and o.partner_account_mode='registered_business'
 and o.partner_verification_status in ('verified','approved') and o.partner_lifecycle_status in ('active','verified') and o.partner_compliance_status in ('clear','compliant','approved','verified','not_required','not_applicable')
 and (o.organization_type ilike '%warehouse%' or o.organization_type_code ilike '%warehouse%' or o.organization_type ilike '%fulfilment%' or o.organization_type_code ilike '%fulfilment%' or o.organization_type ilike '%fulfillment%' or o.organization_type_code ilike '%fulfillment%')
 and private.krim_has_permission((select auth.uid()),o.id,'partner.manage')) else false end);

revoke all on function public.krim_warehouse_create_task(bigint,uuid,text,text,text,text,text,numeric,text,text,text,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.krim_warehouse_create_task(bigint,uuid,text,text,text,text,text,numeric,text,text,text,text,text,text,uuid) to authenticated;
revoke all on function public.krim_warehouse_transition_task(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.krim_warehouse_transition_task(uuid,text,uuid,text) to authenticated;
revoke all on function public.krim_warehouse_list_tasks(text) from public,anon,authenticated;
grant execute on function public.krim_warehouse_list_tasks(text) to authenticated;
revoke all on function public.krim_warehouse_dashboard() from public,anon,authenticated;
grant execute on function public.krim_warehouse_dashboard() to authenticated;
revoke all on function public.krim_warehouse_register_evidence(uuid,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.krim_warehouse_register_evidence(uuid,text,text,text,timestamptz) to authenticated;
revoke all on function public.krim_warehouse_list_events(uuid) from public,anon,authenticated;
grant execute on function public.krim_warehouse_list_events(uuid) to authenticated;
revoke all on function public.krim_warehouse_list_evidence(uuid) from public,anon,authenticated;
grant execute on function public.krim_warehouse_list_evidence(uuid) to authenticated;
