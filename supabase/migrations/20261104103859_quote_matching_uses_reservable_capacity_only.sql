do $$
declare v_def text;v_start integer;v_end integer;v_prefix text;v_suffix text;v_cte text;
begin
 select pg_get_functiondef('public.krim_internal_check_network_capability(bigint)'::regprocedure) into v_def;
 v_start:=position(' capacity_partners as (' in v_def);v_end:=position(' select (select count(*) from eligible_partners)' in v_def);
 if v_start=0 or v_end=0 or v_end<=v_start then raise exception 'Could not locate capacity CTE in quote matching function';end if;
 v_prefix:=substring(v_def from 1 for v_start-1);v_suffix:=substring(v_def from v_end);
 v_cte:=' capacity_partners as ('||chr(10)||'  select a.organization_id'||chr(10)||
 '  from public.krim_partner_capacity_availability a'||chr(10)||'  join public.krim_capacity_resources r on r.id=a.capacity_resource_id'||chr(10)||
 '  join eligible_partners ep on ep.organization_id=a.organization_id'||chr(10)||'  left join lateral ('||chr(10)||
 '   select coalesce(sum(rq.requested_capacity),0) reserved_capacity'||chr(10)||'   from public.krim_capacity_reservations rq'||chr(10)||
 '   where rq.capacity_availability_id=a.id'||chr(10)||
 '    and (rq.status=''confirmed'' or (rq.status=''held'' and (rq.hold_expires_at is null or rq.hold_expires_at>now())))'||chr(10)||
 '  ) used on true'||chr(10)||'  where a.transport_mode_id=v_mode_id and a.status=''available'''||chr(10)||
 '   and a.metadata->>''verification_state''=''verified'''||chr(10)||
 '   and a.available_from<=v_requested_at and a.available_until>v_requested_at'||chr(10)||
 '   and (a.booking_window_start is null or a.booking_window_start<=v_requested_at)'||chr(10)||
 '   and (a.booking_window_end is null or a.booking_window_end>v_requested_at)'||chr(10)||
 '   and a.availability_type in (''vehicle'',''weight'') and r.resource_type=''vehicle'' and r.transport_mode_id=v_mode_id'||chr(10)||
 '   and r.status=''available'' and r.metadata->>''verification_state''=''verified'' and r.location_id=v_origin_location'||chr(10)||
 '   and r.available_from<=v_requested_at and r.available_until>v_requested_at and lower(a.capacity_unit)=lower(r.capacity_unit)'||chr(10)||
 '   and ((a.availability_type=''vehicle'' and least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=1)'||chr(10)||
 '    or (a.availability_type=''weight'' and v_weight is not null and v_weight>0 and case lower(btrim(a.capacity_unit))'||chr(10)||
 '     when ''kg'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
 '     when ''kgs'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
 '     when ''kilogram'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
 '     when ''kilograms'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
 '     when ''t'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
 '     when ''tonne'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
 '     when ''tonnes'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
 '     when ''metric ton'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
 '     when ''metric tons'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
 '     else false end))'||chr(10)||' )'||chr(10);
 v_def:=v_prefix||v_cte||v_suffix;
 if position('krim_network_capacity' in v_def)>0 then raise exception 'Legacy capacity table still present in quote matcher';end if;
 execute v_def;
end $$;