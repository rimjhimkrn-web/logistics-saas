-- REVIEW-ONLY: customer-safe partner availability preflight.
-- No production or staging execution is authorised by this file.
--
-- The present capability model stores broad country/region coverage, mode,
-- weight ceiling and verification, but does not encode a complete origin ->
-- destination lane, live capacity window or service-specific restrictions.
-- Therefore this function NEVER returns "matched" or confirms a booking.
-- It returns only:
--   no_verified_provider: no currently verified/active partner capability
--   review_required: at least one broadly eligible capability exists, but
--                    human route/capacity review is still required.
--
-- This is deliberately a safe discovery/preflight response, not a booking
-- authorisation. Shipment creation remains a request for review only.

create or replace function public.krim_customer_partner_availability_preflight(
  p_customer_organization_id bigint,
  p_origin_location_id bigint,
  p_destination_location_id bigint,
  p_transport_mode text,
  p_total_weight_kg numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_origin_country bigint;
  v_destination_country bigint;
  v_origin_region text;
  v_destination_region text;
  v_mode_id bigint;
  v_candidate_count integer := 0;
begin
  if auth.uid() is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;

  if p_customer_organization_id is null
     or not private.krim_has_organization_access(auth.uid(),p_customer_organization_id)
     or not private.krim_has_permission(auth.uid(),p_customer_organization_id,'shipment.create') then
    raise exception using errcode='42501', message='Customer organisation access denied';
  end if;

  if p_origin_location_id is null or p_destination_location_id is null
     or p_origin_location_id=p_destination_location_id then
    raise exception using errcode='22023', message='Choose two different valid locations';
  end if;

  if p_transport_mode is null or p_transport_mode not in
    ('road','rail','ocean','air','multimodal','warehouse_transfer','specialist') then
    raise exception using errcode='22023', message='Unsupported transport mode';
  end if;

  if p_total_weight_kg is not null and p_total_weight_kg <= 0 then
    raise exception using errcode='22023', message='Weight must be positive';
  end if;

  select l.country_id, coalesce(l.state_region,l.region,'')
    into v_origin_country,v_origin_region
  from public.krim_locations l
  join public.krim_countries c on c.id=l.country_id and c.is_active=true
  where l.id=p_origin_location_id and l.is_active=true;

  if v_origin_country is null then
    raise exception using errcode='22023', message='Origin location is unavailable';
  end if;

  select l.country_id, coalesce(l.state_region,l.region,'')
    into v_destination_country,v_destination_region
  from public.krim_locations l
  join public.krim_countries c on c.id=l.country_id and c.is_active=true
  where l.id=p_destination_location_id and l.is_active=true;

  if v_destination_country is null then
    raise exception using errcode='22023', message='Destination location is unavailable';
  end if;

  select tm.id into v_mode_id
  from public.krim_transport_modes tm
  where tm.code=case p_transport_mode\n    when 'warehouse_transfer' then 'WAREHOUSE'\n    else upper(p_transport_mode)\n  end\n    and tm.is_active=true
  limit 1;

  if v_mode_id is null then
    return pg_catalog.jsonb_build_object(
      'status','no_verified_provider',
      'booking_allowed',false,
      'message','No active transport mode is configured for this request.'
    );
  end if;

  -- Only currently active, verified capabilities attached to active partner
  -- organisations with completed verification/compliance are considered.
  -- Candidate data is not returned to the customer.
  select count(distinct pc.organization_id)::integer
    into v_candidate_count
  from public.krim_partner_capabilities pc
  join public.krim_organizations po on po.id=pc.organization_id
  where pc.active=true
    and pc.verification_status='verified'
    and pc.transport_mode_id=v_mode_id
    and pc.coverage_country_id=v_origin_country
    and pc.coverage_country_id=v_destination_country
    and (pc.effective_from is null or pc.effective_from <= pg_catalog.now())
    and (pc.effective_until is null or pc.effective_until > pg_catalog.now())
    and (pc.max_weight_kg is null or p_total_weight_kg is null or pc.max_weight_kg >= p_total_weight_kg)
    and po.status='active'
    and po.partner_verification_status='verified'
    and po.partner_compliance_status='clear'
    and po.partner_lifecycle_status='active';

  if v_candidate_count=0 then
    return pg_catalog.jsonb_build_object(
      'status','no_verified_provider',
      'booking_allowed',false,
      'candidate_count',0,
      'message','No verified partner capability is currently registered for this request. You may submit a free coverage enquiry; no booking or charge is created.'
    );
  end if;

  -- The schema currently has no validated end-to-end lane, current vehicle
  -- capacity window and cargo-specific eligibility in this preflight.
  -- Never upgrade broad country coverage into a false confirmed match.
  return pg_catalog.jsonb_build_object(
    'status','review_required',
    'booking_allowed',false,
    'candidate_count',v_candidate_count,
    'message','Potential partner capability exists, but KRIM must verify the exact route, service, cargo and available capacity before confirming a booking.'
  );
end;
$function$;

revoke all on function public.krim_customer_partner_availability_preflight(bigint,bigint,bigint,text,numeric)
  from public, anon;
grant execute on function public.krim_customer_partner_availability_preflight(bigint,bigint,bigint,text,numeric)
  to authenticated;

-- Required staging tests:
-- 1. Unauthenticated and unrelated-org users are denied.
-- 2. Invalid/inactive origin or destination is rejected.
-- 3. No active verified capability returns no_verified_provider.
-- 4. Expired, pending, inactive, wrong-mode, wrong-country, over-weight
--    capability and inactive/unverified/non-compliant partner are excluded.
-- 5. Broadly eligible capability returns review_required, never matched.
-- 6. Response includes no partner names, organisation IDs, rates or notes.
-- 7. No shipment, quote, assignment, payment or ledger rows are created.
-- 8. Confirm no booking UI treats review_required as a confirmed booking.
--
-- Current production baseline (read-only audit): one capability row, inactive
-- and pending; zero active verified capabilities. Expected current response:
-- no_verified_provider, booking_allowed=false.
