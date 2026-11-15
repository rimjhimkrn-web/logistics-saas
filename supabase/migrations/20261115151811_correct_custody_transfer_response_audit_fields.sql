alter table public.krim_shipment_leg_custody_transfers
 add column if not exists responded_by uuid references auth.users(id),
 add column if not exists responded_at timestamptz;

create or replace function public.krim_respond_to_leg_custody_transfer(
 p_transfer_id bigint,p_accept boolean,p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_user uuid:=auth.uid();
 v_transfer public.krim_shipment_leg_custody_transfers%rowtype;
 v_to public.krim_shipment_legs%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 if p_transfer_id is null or p_accept is null or (not p_accept and nullif(btrim(p_reason),'') is null) then
  raise exception 'Transfer, response and rejection reason when rejecting are required' using errcode='22023';
 end if;
 select * into v_transfer from public.krim_shipment_leg_custody_transfers
 where id=p_transfer_id for update;
 if v_transfer.id is null then raise exception 'Custody transfer not found' using errcode='P0002'; end if;
 if not private.krim_has_permission(v_user,v_transfer.receiving_organization_id,'partner.manage') then
  raise exception 'Active receiving-partner membership and partner.manage permission required' using errcode='42501';
 end if;
 if v_transfer.status='accepted' and p_accept then
  return jsonb_build_object('replayed',true,'transfer',to_jsonb(v_transfer));
 elsif v_transfer.status='rejected' and not p_accept then
  return jsonb_build_object('replayed',true,'transfer',to_jsonb(v_transfer));
 elsif v_transfer.status<>'pending' then
  raise exception 'Custody transfer is no longer awaiting a response' using errcode='23514';
 end if;
 select * into v_to from public.krim_shipment_legs where id=v_transfer.to_leg_id for update;
 if v_to.shipment_id<>v_transfer.shipment_id or v_to.partner_organization_id<>v_transfer.receiving_organization_id then
  raise exception 'Receiving leg or partner binding has changed' using errcode='23514';
 end if;
 if p_accept then
  if not exists(
   select 1 from public.krim_shipment_partner_assignments a
   where a.shipment_id=v_to.shipment_id and a.shipment_leg_id=v_to.id
    and a.partner_organization_id=v_to.partner_organization_id
    and a.status in ('accepted','active')
  ) or not exists(
   select 1 from public.krim_capacity_leg_bindings b
   join public.krim_capacity_reservations r on r.id=b.reservation_id
   where b.shipment_id=v_to.shipment_id and b.shipment_leg_id=v_to.id
    and b.status='confirmed' and r.status='confirmed'
    and r.organization_id=v_to.partner_organization_id
  ) then
   raise exception 'Receiving assignment and confirmed physical capacity must remain valid at acceptance' using errcode='23514';
  end if;
  update public.krim_shipment_leg_custody_transfers
   set status='accepted',accepted_by=v_user,accepted_at=now(),
    responded_by=v_user,responded_at=now(),response_reason=null,updated_at=now()
   where id=v_transfer.id returning * into v_transfer;
 else
  update public.krim_shipment_leg_custody_transfers
   set status='rejected',responded_by=v_user,responded_at=now(),
    response_reason=left(btrim(p_reason),2000),updated_at=now()
   where id=v_transfer.id returning * into v_transfer;
 end if;
 insert into public.krim_shipment_leg_custody_transfer_events(transfer_id,event_type,actor_user_id,payload)
 values(v_transfer.id,case when p_accept then 'custody_transfer.accepted' else 'custody_transfer.rejected' end,
  v_user,jsonb_build_object('receiving_organization_id',v_transfer.receiving_organization_id,'reason',v_transfer.response_reason));
 return jsonb_build_object('replayed',false,'transfer',to_jsonb(v_transfer));
end;
$function$;

revoke all on function public.krim_respond_to_leg_custody_transfer(bigint,boolean,text) from public,anon;
grant execute on function public.krim_respond_to_leg_custody_transfer(bigint,boolean,text) to authenticated;
