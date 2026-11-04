-- Require warehouse facility country codes to exist in KRIM's active ISO country catalogue.
do $patch$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text)'::regprocedure) into v_def;
 v_old:='if upper(btrim(coalesce(p_country_code,''''))) !~ ''^[A-Z]{2}$'' then raise exception ''Use a two-letter ISO country code'' using errcode=''22023'';end if;';
 v_new:=v_old||E'\n if not exists(select 1 from public.krim_countries c where upper(coalesce(c.iso2_code,c.code))=upper(btrim(p_country_code)) and c.is_active) then raise exception ''Country code is not present in KRIM active country catalogue'' using errcode=''22023'';end if;';
 if position('KRIM active country catalogue' in v_def)=0 then if position(v_old in v_def)=0 then raise exception 'Could not locate country format validation';end if;execute replace(v_def,v_old,v_new);end if;
end;$patch$;