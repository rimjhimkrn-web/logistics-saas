create or replace function public.krim_request_shipment_return(p_shipment_id bigint,p_shipment_leg_id bigint,p_reason text,p_item_manifest jsonb,p_requested_pickup_at timestamptz,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_user uuid:=auth.uid(); v_shipment public.krim_shipments%rowtype; v_leg public.krim_shipment_legs%rowtype;
 v_partner bigint; v_return public.krim_shipment_returns%rowtype; v_reason text:=btrim(coalesce(p_reason,''));
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_shipment_id is null or p_idempotency_key is null or length(v_reason)<5 or length(v_reason)>2000
  or jsonb_typeof(p_item_manifest)<>'array' or jsonb_array_length(p_item_manifest) not between 1 and 100 then
  raise exception 'Shipment, reason, 1–100 item manifest entries and idempotency key are required' using errcode='22023';
 end if;
 if exists(select 1 from jsonb_array_elements(p_item_manifest) x
  where jsonb_typeof(x)<>'object' or nullif(btrim(x->>'description'),'') is null
   or coalesce(x->>'quantity','') !~ '^[0-9]+([.][0-9]+)?$' or (x->>'quantity')::numeric<=0
   or nullif(btrim(x->>'unit'),'') is null) then
  raise exception 'Each return item requires description, positive quantity and unit' using errcode='22023';
 end if;
 select * into v_shipment from public.krim_shipments where id=p_shipment_id for update;
 if not found then raise exception 'Shipment not found' using errcode='P0002'; end if;
 if not private.krim_has_permission(v_user,v_shipment.customer_organization_id,'shipment.update') then raise exception 'Customer shipment update permission required' using errcode='42501'; end if;
 if p_shipment_leg_id is not null then
  select * into v_leg from public.krim_shipment_legs where id=p_shipment_leg_id and shipment_id=p_shipment_id for share;
  if not found or v_leg.partner_organization_id is null or v_leg.status not in ('completed','delivered') then raise exception 'Return must reference a completed shipment leg with an assigned partner' using errcode='23514'; end if;
  v_partner:=v_leg.partner_organization_id;
 else
  if v_shipment.status<>'delivered' then raise exception 'Shipment-wide return is available only after delivery' using errcode='23514'; end if;
  select l.partner_organization_id into v_partner from public.krim_shipment_legs l where l.shipment_id=p_shipment_id and l.partner_organization_id is not null order by l.leg_sequence desc limit 1;
  if v_partner is null then raise exception 'Delivered shipment has no identifiable final partner' using errcode='23514'; end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('krim_return:'||v_shipment.customer_organization_id::text||':'||p_idempotency_key::text,0));
 select * into v_return from public.krim_shipment_returns where customer_organization_id=v_shipment.customer_organization_id and idempotency_key=p_idempotency_key;
 if found then
  if v_return.shipment_id<>p_shipment_id or v_return.shipment_leg_id is distinct from p_shipment_leg_id or v_return.reason<>v_reason or v_return.item_manifest<>p_item_manifest then raise exception 'Return idempotency key reused with conflicting request' using errcode='23505'; end if;
  return jsonb_build_object('replayed',true,'return',to_jsonb(v_return));
 end if;
 insert into public.krim_shipment_returns(shipment_id,shipment_leg_id,customer_organization_id,partner_organization_id,requested_by,reason,item_manifest,requested_pickup_at,idempotency_key)
 values(p_shipment_id,p_shipment_leg_id,v_shipment.customer_organization_id,v_partner,v_user,v_reason,p_item_manifest,p_requested_pickup_at,p_idempotency_key) returning * into v_return;
 insert into public.krim_audit_events(actor_user_id,organization_id,event_type,entity_type,entity_id,source,metadata)
 values(v_user,v_shipment.customer_organization_id,'shipment.return.requested','shipment_return',v_return.id::text,'rpc',jsonb_build_object('shipment_id',p_shipment_id,'partner_organization_id',v_partner,'shipment_leg_id',p_shipment_leg_id));
 return jsonb_build_object('replayed',false,'return',to_jsonb(v_return));
end;
$fn$;