-- Enforce a current, time-limited compliance clearance at every partner
-- commercial execution boundary. Historical status strings alone are not proof.
create or replace function private.krim_partner_compliance_is_current(p_organization_id bigint)
returns boolean language sql stable security definer set search_path='' as $$
 select exists (
  select 1 from public.krim_organizations o
  join lateral (
   select r.status,r.valid_until from public.krim_partner_compliance_reviews r
   where r.organization_id=o.id order by r.reviewed_at desc,r.id desc limit 1
  ) latest on true
  where o.id=p_organization_id and o.status='active'
   and o.partner_account_mode='registered_business'
   and o.partner_verification_status='verified'
   and o.partner_compliance_status='compliant'
   and o.partner_lifecycle_status in ('approved','active')
   and latest.status='approved' and latest.valid_until is not null and latest.valid_until>now()
 );
$$;
revoke all on function private.krim_partner_compliance_is_current(bigint) from public,anon,authenticated;

DO $patch$
DECLARE d text; old_text text; new_text text;
BEGIN
 SELECT pg_get_functiondef('public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamp with time zone,timestamp with time zone,text[],text)'::regprocedure) INTO d;
 old_text := $old$if not exists(select 1 from public.krim_organizations o
  where o.id=p_organization_id and lower(o.status)='active'
   and o.partner_account_mode='registered_business'
   and o.organization_type in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
   and lower(coalesce(o.partner_verification_status,'')) in ('verified','approved')
   and lower(coalesce(o.partner_lifecycle_status,'')) in ('active','verified')
   and lower(coalesce(o.partner_compliance_status,'')) in ('clear','compliant','approved','verified','not_required','not_applicable')) then$old$;
 new_text := $new$if not exists(select 1 from public.krim_organizations o
  where o.id=p_organization_id
   and o.organization_type in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator'))
  or not private.krim_partner_compliance_is_current(p_organization_id) then$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Capacity registration patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_partner_reserve_shipment_leg_capacity(bigint,timestamp with time zone,timestamp with time zone,text)'::regprocedure) INTO d;
 old_text := $old$if not found or coalesce(v_org.status,'')<>'active' or coalesce(v_org.partner_account_mode,'')<>'registered_business'
   or coalesce(v_org.partner_verification_status,'') not in ('verified','approved')
   or coalesce(v_org.partner_lifecycle_status,'') not in ('active','verified')
   or coalesce(v_org.partner_compliance_status,'') not in ('clear','compliant','approved','verified','not_required','not_applicable') then$old$;
 new_text := $new$if not found or not private.krim_partner_compliance_is_current(v_org.id) then$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Capacity reservation patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure) INTO d;
 old_text := $old$IF NOT EXISTS (
      SELECT 1 FROM public.krim_organizations o
      WHERE o.id=v_assignment.partner_organization_id
        AND o.status='active'
        AND o.partner_account_mode='registered_business'
        AND EXISTS (
          SELECT 1 FROM public.krim_partner_capabilities pc
          WHERE pc.organization_id=o.id AND pc.active IS TRUE
            AND pc.verification_status='verified'
            AND (pc.effective_from IS NULL OR pc.effective_from<=now())
            AND (pc.effective_until IS NULL OR pc.effective_until>now())
        )
        AND o.partner_verification_status IN ('verified','approved')
        AND o.partner_lifecycle_status IN ('active','verified')
        AND o.partner_compliance_status IN ('clear','compliant','approved','verified','not_required','not_applicable')
    ) THEN$old$;
 new_text := $new$IF NOT private.krim_partner_compliance_is_current(v_assignment.partner_organization_id) THEN$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Assignment acceptance patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[])'::regprocedure) INTO d;
 old_text := $old$IF lower(coalesce(v_org.partner_verification_status,'')) NOT IN ('verified','approved')
    OR lower(coalesce(v_org.partner_lifecycle_status,'')) NOT IN ('active','verified')
    OR lower(coalesce(v_org.partner_compliance_status,'')) NOT IN ('clear','compliant','approved','verified','not_required','not_applicable')
  THEN$old$;
 new_text := $new$IF NOT private.krim_partner_compliance_is_current(p_organization_id)
  THEN$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Capability submission patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure) INTO d;
 old_text := $old$if v_decision='approved' and (
  coalesce(v_org_mode,'')<>'registered_business' or coalesce(v_org_status,'')<>'active'
  or coalesce(v_org_lifecycle,'') not in ('active','verified') or coalesce(v_org_verification,'') not in ('verified','approved')
  or coalesce(v_org_compliance,'') not in ('clear','compliant','approved','verified','not_required','not_applicable')
 ) then$old$;
 new_text := $new$if v_decision='approved' and not private.krim_partner_compliance_is_current(v_org_id) then$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Capability approval patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_admin_review_capacity_resource(bigint,text,text)'::regprocedure) INTO d;
 old_text := $old$if coalesce(v_org_type,'') not in ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator') or v_org_mode is distinct from 'registered_business' or v_org_status is distinct from 'active'
   or coalesce(v_org_lifecycle,'') not in ('active','verified')
   or coalesce(v_org_verification,'') not in ('verified','approved')
   or coalesce(v_org_compliance,'') not in ('clear','compliant','approved','verified','not_required','not_applicable') then$old$;
 new_text := $new$if coalesce(v_org_type,'') not in ('partner','carrier','warehouse','forwarder','logistics_provider','warehouse_operator')
   or not private.krim_partner_compliance_is_current(v_org_id) then$new$;
 IF position(new_text in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Capacity review patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;

 SELECT pg_get_functiondef('public.krim_admin_review_partner_compliance(bigint,text,jsonb,text,timestamp with time zone)'::regprocedure) INTO d;
 old_text := $old$if p_valid_until is not null and (p_valid_until<=now() or p_valid_until>now()+interval '365 days') then$old$;
 new_text := $new$if v_decision='approved' and p_valid_until is null then
   raise exception using errcode='22023',message='An approval expiry date is required for every compliance clearance';
 end if;
 if p_valid_until is not null and (p_valid_until<=now() or p_valid_until>now()+interval '365 days') then$new$;
 IF position('An approval expiry date is required' in d)=0 THEN
  IF position(old_text in d)=0 THEN RAISE EXCEPTION 'Compliance expiry patch target not found'; END IF;
  d:=replace(d,old_text,new_text); EXECUTE d;
 END IF;
END
$patch$;
