-- Remove direct browser writes to receipt records. Controlled task RPCs own this lifecycle.
revoke insert,update,delete on public.krim_warehouse_receipts from anon,authenticated;
grant select on public.krim_warehouse_receipts to authenticated;
-- Inventory movement RPC now requires an administrator-approved facility.
do $patch$
declare v_def text;v_old text;v_new text;
begin
 select pg_get_functiondef('public.krim_warehouse_record_movement(bigint,uuid,text,numeric,text,uuid,text,text,text,text,text,text,text,text)'::regprocedure) into v_def;
 v_old:='where f.id=p_facility_id and f.organization_id=p_organization_id and f.status=''active''';
 v_new:='where f.id=p_facility_id and f.organization_id=p_organization_id and f.status=''active'' and f.review_status=''approved''';
 if position(v_new in v_def)=0 then if position(v_old in v_def)=0 then raise exception 'Could not locate active facility guard';end if; execute replace(v_def,v_old,v_new);end if;
end;$patch$;