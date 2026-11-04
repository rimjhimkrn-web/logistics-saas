-- Enforce route-scoped partner capability and verified driver eligibility.
-- This migration follows 20261104153500_require_verified_partner_capability.sql.

CREATE OR REPLACE FUNCTION private.krim_partner_capability_covers_shipment(
  p_organization_id bigint,
  p_shipment_id bigint
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.krim_shipments s
    JOIN public.krim_locations origin ON origin.id=s.origin_location_id AND origin.is_active IS TRUE
    JOIN public.krim_locations destination ON destination.id=s.destination_location_id AND destination.is_active IS TRUE
    JOIN public.krim_countries origin_country ON origin_country.id=origin.country_id AND origin_country.is_active IS TRUE
    JOIN public.krim_countries destination_country ON destination_country.id=destination.country_id AND destination_country.is_active IS TRUE
    JOIN public.krim_transport_modes requested_mode
      ON requested_mode.is_active IS TRUE
     AND upper(requested_mode.code)=upper(s.requested_transport_mode)
    WHERE s.id=p_shipment_id
      AND p_organization_id IS NOT NULL
      AND s.requested_transport_mode IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=p_organization_id
          AND pc.transport_mode_id=requested_mode.id
          AND pc.coverage_country_id=origin.country_id
          AND pc.active IS TRUE AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
          AND (pc.max_weight_kg IS NULL OR pc.max_weight_kg>=coalesce(s.total_weight_kg,0))
          AND (nullif(btrim(pc.coverage_region),'') IS NULL
            OR lower(btrim(pc.coverage_region)) IN (lower(origin_country.name),lower(coalesce(origin.state_region,'')),lower(coalesce(origin.region,''))))
      )
      AND EXISTS (
        SELECT 1 FROM public.krim_partner_capabilities pc
        WHERE pc.organization_id=p_organization_id
          AND pc.transport_mode_id=requested_mode.id
          AND pc.coverage_country_id=destination.country_id
          AND pc.active IS TRUE AND pc.verification_status='verified'
          AND (pc.effective_from IS NULL OR pc.effective_from<=now())
          AND (pc.effective_until IS NULL OR pc.effective_until>now())
          AND (pc.max_weight_kg IS NULL OR pc.max_weight_kg>=coalesce(s.total_weight_kg,0))
          AND (nullif(btrim(pc.coverage_region),'') IS NULL
            OR lower(btrim(pc.coverage_region)) IN (lower(destination_country.name),lower(coalesce(destination.state_region,'')),lower(coalesce(destination.region,''))))
      )
  );
$function$;

REVOKE ALL ON FUNCTION private.krim_partner_capability_covers_shipment(bigint,bigint)
  FROM PUBLIC, anon, authenticated;

DO $krim$
DECLARE d text;
BEGIN
  SELECT pg_get_functiondef('public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)'::regprocedure) INTO d;
  IF position('Opportunity is no longer open for bids' in d)=0 THEN RAISE EXCEPTION 'quote opportunity anchor missing'; END IF;
  d:=replace(d,
    'IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = ''P0002'', message = ''Opportunity is no longer open for bids'';
  END IF;',
    'IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = ''P0002'', message = ''Opportunity is no longer open for bids'';
  END IF;
  IF NOT private.krim_partner_capability_covers_shipment(v_partner_organization_id,v_opportunity.shipment_id) THEN
    RAISE EXCEPTION USING errcode = ''42501'', message = ''Partner capability does not cover the shipment transport mode, both route countries, region or weight limit'';
  END IF;');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_award_partner_quote(bigint)'::regprocedure) INTO d;
  IF position('Partner quote shipment does not match the opportunity' in d)=0 THEN RAISE EXCEPTION 'award shipment anchor missing'; END IF;
  d:=replace(d,
    'IF NOT FOUND OR v_shipment.customer_organization_id <> v_opportunity.customer_organization_id THEN
    RAISE EXCEPTION USING errcode=''23503'', message=''Partner quote shipment does not match the opportunity'';
  END IF;',
    'IF NOT FOUND OR v_shipment.customer_organization_id <> v_opportunity.customer_organization_id THEN
    RAISE EXCEPTION USING errcode=''23503'', message=''Partner quote shipment does not match the opportunity'';
  END IF;
  IF NOT private.krim_partner_capability_covers_shipment(v_quote.partner_organization_id,v_shipment.id) THEN
    RAISE EXCEPTION USING errcode=''42501'', message=''Partner capability no longer covers the shipment route, transport mode or weight'';
  END IF;');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure) INTO d;
  IF position('SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_assignment.shipment_id FOR UPDATE;' in d)=0 THEN RAISE EXCEPTION 'assignment shipment select anchor missing'; END IF;
  d:=replace(d,
    'SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_assignment.shipment_id FOR UPDATE;',
    'SELECT * INTO v_shipment FROM public.krim_shipments WHERE id=v_assignment.shipment_id FOR UPDATE;
  IF p_accept AND NOT private.krim_partner_capability_covers_shipment(v_assignment.partner_organization_id,v_shipment.id) THEN
    RAISE EXCEPTION USING errcode=''42501'', message=''Partner capability no longer covers the shipment route, transport mode or weight'';
  END IF;');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_assign_driver_to_partner_shipment(bigint,uuid)'::regprocedure) INTO d;
  IF position('Driver must have an active driver membership' in d)=0 THEN RAISE EXCEPTION 'driver membership anchor missing'; END IF;
  d:=replace(d,
    'if v_driver_org is null then
    raise exception using errcode=''42501'', message=''Driver must have an active driver membership in this partner organization'';
  end if;',
    'if v_driver_org is null then
    raise exception using errcode=''42501'', message=''Driver must have an active driver membership in this partner organization'';
  end if;
  if not exists (
    select 1 from public.krim_driver_profiles dp
    where dp.user_id=p_driver_user_id and dp.organization_id=v_pa.partner_organization_id
      and dp.verification_status in (''verified'',''approved'')
      and nullif(btrim(dp.licence_number),'''') is not null
  ) then
    raise exception using errcode=''42501'', message=''Driver identity and licence verification must be approved before dispatch'';
  end if;');
  IF d NOT LIKE '%Driver identity and licence verification must be approved before dispatch%' THEN RAISE EXCEPTION 'driver verification guard patch failed'; END IF;

  d:=replace(d,
    'select * into v_ship from public.krim_shipments where id=v_pa.shipment_id for update;',
    'select * into v_ship from public.krim_shipments where id=v_pa.shipment_id for update;
  if not exists (
    select 1 from public.krim_organizations o
    where o.id=v_pa.partner_organization_id and o.status=''active''
      and o.partner_account_mode=''registered_business''
      and o.partner_verification_status in (''verified'',''approved'')
      and o.partner_lifecycle_status in (''active'',''verified'')
      and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')
  ) or not private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) then
    raise exception using errcode=''42501'', message=''Partner commercial eligibility or verified route capability is no longer valid'';
  end if;');
  IF d NOT LIKE '%verified route capability is no longer valid%' THEN RAISE EXCEPTION 'dispatch eligibility guard patch failed'; END IF;

  d:=replace(d,
    'if not exists (
    select 1 from public.krim_organizations o
    where o.id=v_pa.partner_organization_id and o.status=''active''
      and o.partner_account_mode=''registered_business''
      and o.partner_verification_status in (''verified'',''approved'')
      and o.partner_lifecycle_status in (''active'',''verified'')
      and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')
  ) or not private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) then
    raise exception using errcode=''42501'', message=''Partner commercial eligibility or verified route capability is no longer valid'';
  end if;
  if not found then raise exception using errcode=''22023'', message=''Shipment not found''; end if;',
    'if not found then raise exception using errcode=''22023'', message=''Shipment not found''; end if;
  if not exists (
    select 1 from public.krim_organizations o
    where o.id=v_pa.partner_organization_id and o.status=''active''
      and o.partner_account_mode=''registered_business''
      and o.partner_verification_status in (''verified'',''approved'')
      and o.partner_lifecycle_status in (''active'',''verified'')
      and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable'')
  ) or not private.krim_partner_capability_covers_shipment(v_pa.partner_organization_id,v_ship.id) then
    raise exception using errcode=''42501'', message=''Partner commercial eligibility or verified route capability is no longer valid'';
  end if;');
  EXECUTE d;

  SELECT pg_get_functiondef('public.krim_list_dispatchable_drivers(bigint)'::regprocedure) INTO d;
  IF position('declare v_org bigint;' in d)=0 THEN RAISE EXCEPTION 'driver list declaration anchor missing'; END IF;
  d:=replace(d,'declare v_org bigint;','declare v_org bigint; v_shipment bigint;');
  d:=replace(d,
    'select a.partner_organization_id into v_org
  from public.krim_shipment_partner_assignments a',
    'select a.partner_organization_id,a.shipment_id into v_org,v_shipment
  from public.krim_shipment_partner_assignments a');
  IF position('a.shipment_id into v_org,v_shipment' in d)=0 THEN RAISE EXCEPTION 'driver list shipment select patch failed'; END IF;
  d:=replace(d,
    'if not public.krim_has_permission(auth.uid(), v_org, ''shipment.dispatch'') then
    raise exception using errcode=''42501'', message=''You do not have dispatch permission for this partner organization'';
  end if;',
    'if not public.krim_has_permission(auth.uid(), v_org, ''shipment.dispatch'') then
    raise exception using errcode=''42501'', message=''You do not have dispatch permission for this partner organization'';
  end if;
  if not exists (select 1 from public.krim_organizations o where o.id=v_org
    and o.status=''active'' and o.partner_account_mode=''registered_business''
    and o.partner_verification_status in (''verified'',''approved'')
    and o.partner_lifecycle_status in (''active'',''verified'')
    and o.partner_compliance_status in (''clear'',''compliant'',''approved'',''verified'',''not_required'',''not_applicable''))
    or not private.krim_partner_capability_covers_shipment(v_org,v_shipment) then
    raise exception using errcode=''42501'', message=''Partner commercial eligibility or verified route capability is not valid for this shipment'';
  end if;');
  d:=replace(d,
    'left join public.krim_driver_profiles p on p.user_id=m.user_id',
    'left join public.krim_driver_profiles p on p.user_id=m.user_id and p.organization_id=m.organization_id');
  d:=replace(d,
    'where m.organization_id=v_org and lower(m.role)=''driver'' and lower(m.status)=''active''',
    'where m.organization_id=v_org and lower(m.role)=''driver'' and lower(m.status)=''active''
    and exists (select 1 from public.krim_driver_profiles dp
      where dp.user_id=m.user_id and dp.organization_id=m.organization_id
        and dp.verification_status in (''verified'',''approved'')
        and nullif(btrim(dp.licence_number),'''') is not null)');
  IF d NOT LIKE '%verified route capability is not valid for this shipment%' THEN RAISE EXCEPTION 'driver list partner guard patch failed'; END IF;
  IF d NOT LIKE '%dp.verification_status in (''verified'',''approved'')%' THEN RAISE EXCEPTION 'driver list profile guard patch failed'; END IF;
  EXECUTE d;
END
$krim$;
