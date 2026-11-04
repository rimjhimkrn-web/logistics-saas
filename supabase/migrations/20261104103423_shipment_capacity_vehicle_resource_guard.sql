do $$
declare v_def text;
begin
 select pg_get_functiondef('public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamptz,timestamptz,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,'and r.status=''available'' and r.metadata->>''verification_state''=''verified''',
  'and r.status=''available'' and r.resource_type=''vehicle'' and r.metadata->>''verification_state''=''verified''');
 if position('r.resource_type=''vehicle''' in v_def)=0 then raise exception 'Failed to restrict shipment reservations to vehicle resources';end if;
 execute v_def;
end $$;