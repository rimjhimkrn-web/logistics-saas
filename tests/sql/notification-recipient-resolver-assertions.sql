do $$
declare c integer; p integer; d integer;
begin
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(100,'customer','shipment.lifecycle.confirmed');
  if c <> 1 then raise exception 'customer expected 1 recipient, got %',c; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(100,'partner','shipment.lifecycle.assigned');
  if p <> 1 then raise exception 'partner expected 1 non-driver recipient despite duplicate assignments, got %',p; end if;
  select count(*) into d from krim_internal.resolve_shipment_notification_recipients(100,'partner','shipment.lifecycle.assigned') where member_role='driver';
  if d <> 0 then raise exception 'driver unexpectedly returned'; end if;
  if has_function_privilege('anon','krim_internal.resolve_shipment_notification_recipients(bigint,text,text)','EXECUTE') then
    raise exception 'anon unexpectedly has execute';
  end if;
  if has_function_privilege('authenticated','krim_internal.resolve_shipment_notification_recipients(bigint,text,text)','EXECUTE') then
    raise exception 'authenticated unexpectedly has execute';
  end if;
  if not has_function_privilege('service_role','krim_internal.resolve_shipment_notification_recipients(bigint,text,text)','EXECUTE') then
    raise exception 'service_role is missing execute';
  end if;
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(101,'customer','shipment.lifecycle.exception');
  if c <> 1 then raise exception 'suspended customer member must be excluded; expected owner only, got %',c; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(101,'partner','shipment.lifecycle.assigned');
  if p <> 0 then raise exception 'cancelled partner assignment must produce no recipients, got %',p; end if;
  select count(*) into c from krim_internal.resolve_shipment_notification_recipients(100,'customer','shipment.lifecycle.confirmed') where member_role='finance';
  if c <> 0 then raise exception 'customer finance role unexpectedly received shipment update'; end if;
  select count(*) into p from krim_internal.resolve_shipment_notification_recipients(100,'partner','shipment.lifecycle.assigned') where member_role in ('finance','member');
  if p <> 0 then raise exception 'partner finance/member role unexpectedly received assignment notice'; end if;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(100,null,'shipment.lifecycle.confirmed');
    raise exception 'null recipient type should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(100,'customer','shipment.lifecycle.assigned');
    raise exception 'recipient/intent mismatch should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(100,'customer','unknown.intent');
    raise exception 'unknown intent should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_recipients(999,'customer','shipment.lifecycle.confirmed');
    raise exception 'unknown shipment should fail';
  exception when sqlstate 'P0002' then null;
  end;
end $$;


do $$
declare m record; n integer;
begin
  select * into m from krim_internal.resolve_shipment_notification_intent(
    'shipment.lifecycle.confirmed','prepare_customer_notification');
  if m.recipient_type <> 'customer' or m.intent_code <> 'shipment.lifecycle.confirmed' then
    raise exception 'confirmed workflow mapping incorrect';
  end if;

  select * into m from krim_internal.resolve_shipment_notification_intent(
    'shipment.lifecycle.dispatched','prepare_customer_notification');
  if m.recipient_type <> 'customer' or m.intent_code <> 'shipment.lifecycle.dispatched' then
    raise exception 'dispatched workflow mapping incorrect';
  end if;

  select * into m from krim_internal.resolve_shipment_notification_intent(
    'shipment.lifecycle.delivered','prepare_customer_notification');
  if m.recipient_type <> 'customer' or m.intent_code <> 'shipment.lifecycle.delivered' then
    raise exception 'delivered workflow mapping incorrect';
  end if;

  select * into m from krim_internal.resolve_shipment_notification_intent(
    'shipment.lifecycle.exception','prepare_customer_notification');
  if m.recipient_type <> 'customer' or m.intent_code <> 'shipment.lifecycle.exception' then
    raise exception 'exception workflow mapping incorrect';
  end if;

  select * into m from krim_internal.resolve_shipment_notification_intent(
    'shipment.lifecycle.assigned','prepare_partner_notification');
  if m.recipient_type <> 'partner' or m.intent_code <> 'shipment.lifecycle.assigned' then
    raise exception 'assigned workflow mapping incorrect';
  end if;

  if has_function_privilege('anon','krim_internal.resolve_shipment_notification_intent(text,text)','EXECUTE') then
    raise exception 'anon unexpectedly has intent mapper execute';
  end if;
  if has_function_privilege('authenticated','krim_internal.resolve_shipment_notification_intent(text,text)','EXECUTE') then
    raise exception 'authenticated unexpectedly has intent mapper execute';
  end if;
  if not has_function_privilege('service_role','krim_internal.resolve_shipment_notification_intent(text,text)','EXECUTE') then
    raise exception 'service_role missing intent mapper execute';
  end if;

  begin
    perform * from krim_internal.resolve_shipment_notification_intent(
      'shipment.lifecycle.assigned','prepare_customer_notification');
    raise exception 'workflow/action mismatch should fail';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform * from krim_internal.resolve_shipment_notification_intent(
      'shipment.lifecycle.unknown','prepare_customer_notification');
    raise exception 'unknown workflow should fail';
  exception when sqlstate '22023' then null;
  end;
end $$;
