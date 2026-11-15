do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure);
  v_old := $old$  for update of a skip locked$old$;
  v_new := $new$  for update of r, a skip locked$new$;
  if position(v_old in v_def)=0 then
    raise exception 'Capacity reservation candidate lock clause changed';
  end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
