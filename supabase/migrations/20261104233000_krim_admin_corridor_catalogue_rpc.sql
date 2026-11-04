-- AAL2-only read access to corridor catalogue for the private admin workspace.
create or replace function public.krim_admin_list_corridor_catalogue()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_data jsonb;
begin
 if v_user is null or coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then
  raise exception using errcode='42501',message='AAL2 platform administrator access required';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'corridor_code',c.corridor_code,'corridor_name',c.corridor_name,'origin_country_id',c.origin_country_id,'destination_country_id',c.destination_country_id,'status',c.status) order by c.corridor_name),'[]'::jsonb)
 into v_data from public.krim_network_corridors c;
 return jsonb_build_object('corridors',v_data);
end $$;
revoke all on function public.krim_admin_list_corridor_catalogue() from public,anon;
grant execute on function public.krim_admin_list_corridor_catalogue() to authenticated;