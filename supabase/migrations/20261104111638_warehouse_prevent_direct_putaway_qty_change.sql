-- Put-away is a location operation, not a stock-quantity adjustment.
-- It is performed by krim_warehouse_transition_task, which locks the exact lot.
do $patch$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure) into v_def;
 v_old:='if p_movement_type not in (''receipt'',''putaway'',''pick'',''dispatch'',''adjustment'',''return'',''transfer'') then';
 v_new:='if p_movement_type not in (''receipt'',''pick'',''dispatch'',''adjustment'',''return'',''transfer'') then';
 if position(v_new in v_def)=0 then if position(v_old in v_def)=0 then raise exception 'Could not locate movement type allowlist';end if; execute replace(v_def,v_old,v_new);end if;
end;$patch$;