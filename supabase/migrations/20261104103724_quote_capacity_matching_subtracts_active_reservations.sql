do $$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_internal_check_network_capability(bigint)'::regprocedure) into v_def;
 v_old:='join eligible_partners ep on ep.organization_id=a.organization_id'||chr(10)||'  where a.transport_mode_id=v_mode_id';
 v_new:='join eligible_partners ep on ep.organization_id=a.organization_id'||chr(10)||
  '  left join lateral ('||chr(10)||
  '   select coalesce(sum(rq.requested_capacity),0) reserved_capacity'||chr(10)||
  '   from public.krim_capacity_reservations rq'||chr(10)||
  '   where rq.capacity_availability_id=a.id'||chr(10)||
  '    and (rq.status=''confirmed'' or (rq.status=''held'' and (rq.hold_expires_at is null or rq.hold_expires_at>now())))'||chr(10)||
  '  ) used on true'||chr(10)||
  '  where a.transport_mode_id=v_mode_id';
 if position('left join lateral (' in v_def)=0 then v_def:=replace(v_def,v_old,v_new);end if;
 v_old:='(a.availability_type=''vehicle'' and a.capacity_value>=1 and r.capacity_value>=1)'||chr(10)||
  '    or'||chr(10)||'    (a.availability_type=''weight'' and v_weight is not null and v_weight>0 and'||chr(10)||
  '     case lower(btrim(a.capacity_unit))'||chr(10)||
  '      when ''kg'' then least(a.capacity_value,r.capacity_value)>=v_weight'||chr(10)||
  '      when ''kgs'' then least(a.capacity_value,r.capacity_value)>=v_weight'||chr(10)||
  '      when ''kilogram'' then least(a.capacity_value,r.capacity_value)>=v_weight'||chr(10)||
  '      when ''kilograms'' then least(a.capacity_value,r.capacity_value)>=v_weight'||chr(10)||
  '      when ''t'' then least(a.capacity_value,r.capacity_value)>=v_weight/1000'||chr(10)||
  '      when ''tonne'' then least(a.capacity_value,r.capacity_value)>=v_weight/1000'||chr(10)||
  '      when ''tonnes'' then least(a.capacity_value,r.capacity_value)>=v_weight/1000'||chr(10)||
  '      when ''metric ton'' then least(a.capacity_value,r.capacity_value)>=v_weight/1000'||chr(10)||
  '      when ''metric tons'' then least(a.capacity_value,r.capacity_value)>=v_weight/1000'||chr(10)||
  '      else false'||chr(10)||'     end)';
 v_new:='(a.availability_type=''vehicle'' and least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=1)'||chr(10)||
  '    or'||chr(10)||'    (a.availability_type=''weight'' and v_weight is not null and v_weight>0 and'||chr(10)||
  '     case lower(btrim(a.capacity_unit))'||chr(10)||
  '      when ''kg'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
  '      when ''kgs'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
  '      when ''kilogram'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
  '      when ''kilograms'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight'||chr(10)||
  '      when ''t'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
  '      when ''tonne'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
  '      when ''tonnes'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
  '      when ''metric ton'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
  '      when ''metric tons'' then least(a.capacity_value,r.capacity_value)-used.reserved_capacity>=v_weight/1000'||chr(10)||
  '      else false'||chr(10)||'     end)';
 if position('used.reserved_capacity' in v_def)=0 then v_def:=replace(v_def,v_old,v_new);end if;
 if position('left join lateral (' in v_def)=0 or position('used.reserved_capacity' in v_def)=0 then raise exception 'Failed to include active reservations in quote capacity matching';end if;
 execute v_def;
end $$;