begin;

revoke all on function public.krim_partner_submit_service_area(bigint,text,bigint,text,bigint,text[],text,timestamptz,timestamptz)
  from public, anon, authenticated;
grant execute on function public.krim_partner_submit_service_area(bigint,text,bigint,text,bigint,text[],text,timestamptz,timestamptz)
  to authenticated;

revoke all on function public.krim_partner_submit_service_capability_v2(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[],jsonb)
  from public, anon, authenticated;
grant execute on function public.krim_partner_submit_service_capability_v2(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[],jsonb)
  to authenticated;

revoke all on function public.krim_partner_register_capacity_resource_for_lane(bigint,bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text)
  from public, anon, authenticated;
grant execute on function public.krim_partner_register_capacity_resource_for_lane(bigint,bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text)
  to authenticated;

commit;