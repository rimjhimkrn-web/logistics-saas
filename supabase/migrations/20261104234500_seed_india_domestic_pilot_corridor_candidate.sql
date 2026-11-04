-- Initial domestic pilot corridor candidate.
-- This is a draft catalogue record only; it does not assert route availability or authorise bookings.
insert into public.krim_network_corridors
 (corridor_code,corridor_name,origin_country_id,destination_country_id,origin_location_id,destination_location_id,corridor_type,status,description,constraints,metadata)
select
 'IN-RNC-JSR-DRAFT',
 'Ranchi to Jamshedpur | India domestic pilot candidate',
 c1.id,c2.id,l1.id,l2.id,
 'domestic','draft',
 'Initial India domestic corridor candidate for legal, provider, route and operational review. Not an available or approved service.',
 '{}'::jsonb,
 jsonb_build_object('launch_market','IN','purpose','pilot_candidate','operational_authorisation',false,'commercial_availability',false,'seeded_on','2026-11-04')
from public.krim_countries c1
join public.krim_countries c2 on c2.id=c1.id
join public.krim_locations l1 on l1.city='Ranchi' and l1.country_id=c1.id and coalesce(l1.is_active,false)
join public.krim_locations l2 on l2.city='Jamshedpur' and l2.country_id=c2.id and coalesce(l2.is_active,false)
where c1.code='IN'
on conflict(corridor_code) do nothing;