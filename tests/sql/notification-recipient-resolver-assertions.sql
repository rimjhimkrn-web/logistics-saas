do $$
declare c integer; p integer; d integer;
begin
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(100,'customer');
  if c <> 1 then raise exception 'customer expected 1 recipient, got %',c; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(100,'partner');
  if p <> 1 then raise exception 'partner expected 1 non-driver recipient despite duplicate assignments, got %',p; end if;
  select count(*) into d from krim_internal.resolve_shipment_notification_recipients(100,'partner') where member_role='driver';
  if d <> 0 then raise exception 'driver unexpectedly returned'; end if;
  if has_function_privilege('anon','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'anon unexpectedly has execute';
  end if;
  if has_function_privilege('authenticated','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'authenticated unexpectedly has execute';
  end if;
  if not has_function_privilege('service_role','krim_internal.resolve_shipment_notification_recipients(bigint,text)','EXECUTE') then
    raise exception 'service_role is missing execute';
  end if;
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(101,'customer');
  if c <> 1 then raise exception 'suspended customer member must be excluded; expected owner only, got %',c; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(101,'partner');
  if p <> 0 then raise exception 'cancelled partner assignment must produce no recipients, got %',p; end if;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(100,null);
    raise exception 'null recipient type should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(999,'customer');
    raise exception 'unknown shipment should fail';
  exception when sqlstate 'P0002' then null;
  end;
end $$;
