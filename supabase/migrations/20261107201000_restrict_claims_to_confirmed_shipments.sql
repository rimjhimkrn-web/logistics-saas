-- A claim can only be raised against a confirmed or closed shipment.
create or replace function private.krim_claim_submit(p_customer_organization_id bigint,p_shipment_id bigint,p_claim_type text,p_currency_code text,p_claimed_amount numeric,p_description text,p_exception_id bigint default null)
returns bigint language plpgsql security definer set search_path=public,pg_catalog as $function$
declare v_user uuid:=auth.uid();v_customer_org bigint;v_assignment_id bigint;v_partner_org bigint;v_claim_id bigint;v_number text;
begin
 if v_user is null then raise exception 'Authentication required';end if;
 if p_claim_type not in ('loss','damage','delay','shortage','service_failure','billing','other') then raise exception 'Unsupported claim type';end if;
 if p_claimed_amount is null or p_claimed_amount<0 or p_claimed_amount>999999999999 then raise exception 'Invalid claimed amount';end if;
 if length(trim(coalesce(p_description,'')))<20 then raise exception 'Please provide a clear claim description of at least 20 characters';end if;
 if not exists(select 1 from public.krim_organization_members m join public.krim_organizations o on o.id=m.organization_id where m.organization_id=p_customer_organization_id and m.user_id=v_user and m.status='active' and o.status='active' and o.organization_type in ('customer','shipper','enterprise')) then raise exception 'Active customer organization membership required';end if;
 if not private.krim_has_permission(v_user,p_customer_organization_id,'shipment.update') then raise exception 'Customer shipment.update permission required';end if;
 select customer_organization_id into v_customer_org from public.krim_shipments where id=p_shipment_id and status in ('confirmed','closed');
 if v_customer_org is null or v_customer_org<>p_customer_organization_id then raise exception 'Only confirmed or closed shipments belonging to this customer organization can be claimed';end if;
 if p_exception_id is not null and not exists(select 1 from public.krim_exceptions e where e.id=p_exception_id and e.shipment_id=p_shipment_id) then raise exception 'Exception does not belong to this shipment';end if;
 if not exists(select 1 from public.krim_currencies where code=upper(p_currency_code) and is_active) then raise exception 'Currency is inactive or unsupported';end if;
 select a.id,a.partner_organization_id into v_assignment_id,v_partner_org from public.krim_shipment_partner_assignments a where a.shipment_id=p_shipment_id and a.status in ('accepted','completed') order by coalesce(a.accepted_at,a.created_at) desc limit 1;
 v_number:='KRIM-CLM-'||to_char(now(),'YYYY')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
 insert into public.krim_claims(organization_id,shipment_id,exception_id,claim_number,claim_type,claimant_organization_id,respondent_organization_id,status,currency_code,claimed_amount,approved_amount,description,submitted_at,metadata,responsible_partner_organization_id,assignment_id)
 values(p_customer_organization_id,p_shipment_id,p_exception_id,v_number,p_claim_type,p_customer_organization_id,v_partner_org,'submitted',upper(p_currency_code),p_claimed_amount,0,left(trim(p_description),10000),now(),jsonb_build_object('submission_channel','customer_workspace'),v_partner_org,v_assignment_id) returning id into v_claim_id;
 insert into public.krim_claim_events(claim_id,event_type,actor_user_id,actor_organization_id,event_note,event_data) values(v_claim_id,'submitted',v_user,p_customer_organization_id,'Customer claim submitted.',jsonb_build_object('claim_type',p_claim_type,'shipment_id',p_shipment_id));
 return v_claim_id;
end;$function$;
revoke all on function private.krim_claim_submit(bigint,bigint,text,text,numeric,text,bigint) from public,anon,authenticated;
grant execute on function private.krim_claim_submit(bigint,bigint,text,text,numeric,text,bigint) to authenticated;