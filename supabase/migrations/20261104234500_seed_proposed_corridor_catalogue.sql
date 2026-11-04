-- Candidate corridor catalogue only; never represents a live route or service commitment.
insert into public.krim_network_corridors
(corridor_code,corridor_name,origin_country_id,destination_country_id,origin_location_id,destination_location_id,corridor_type,status,description,constraints,metadata)
select v.code,v.name,v.oc,v.dc,v.ol,v.dl,v.ctype,'draft',v.description,
 jsonb_build_object('operational_status','not_authorised','route_geometry','not_defined','transport_mode','not_assigned','partner_coverage','unverified'),
 jsonb_build_object('catalogue_classification','proposed_candidate','seed_basis','existing_active_location_catalogue','legal_status','not_reviewed','commercial_status','not_open_for_booking')
from (values
('IN-RAN-CCU-CAND','Ranchi – Kolkata | proposed domestic corridor',1::bigint,1::bigint,1::bigint,6::bigint,'domestic','Candidate corridor between existing active location records; geography, permits, mode, provider coverage and serviceability not validated.'),
('IN-RAN-AE-DXB-CAND','Ranchi – Dubai | proposed international corridor',1::bigint,2::bigint,1::bigint,25::bigint,'cross_border','Proposed origin-destination pair only; routing, transit, customs, permits, sanctions, provider coverage and serviceability not validated.'),
('IN-RAN-DE-FRA-CAND','Ranchi – Frankfurt | proposed international corridor',1::bigint,3::bigint,1::bigint,30::bigint,'cross_border','Proposed origin-destination pair only; routing, transit, customs, permits, sanctions, provider coverage and serviceability not validated.'),
('IN-RAN-GB-LON-CAND','Ranchi – London | proposed international corridor',1::bigint,4::bigint,1::bigint,5::bigint,'cross_border','Proposed origin-destination pair only; routing, transit, customs, permits, sanctions, provider coverage and serviceability not validated.'),
('IN-RAN-SG-SIN-CAND','Ranchi – Singapore | proposed international corridor',1::bigint,5::bigint,1::bigint,8::bigint,'cross_border','Proposed origin-destination pair only; routing, transit, customs, permits, sanctions, provider coverage and serviceability not validated.'),
('IN-RAN-US-NYC-CAND','Ranchi – New York | proposed international corridor',1::bigint,6::bigint,1::bigint,26::bigint,'cross_border','Proposed origin-destination pair only; routing, transit, customs, permits, sanctions, provider coverage and serviceability not validated.')
) as v(code,name,oc,dc,ol,dl,ctype,description)
where exists(select 1 from public.krim_locations a where a.id=v.ol and a.is_active)
and exists(select 1 from public.krim_locations b where b.id=v.dl and b.is_active)
on conflict(corridor_code) do nothing;