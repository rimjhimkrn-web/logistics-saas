-- Ensure KRIM's first market (India) exists in the staging country catalogue.
-- Keep it inactive: catalogue presence is not market activation.
insert into public.krim_countries
  (code,name,iso2_code,iso3_code,iso_numeric_code,is_active,reference_source,reference_updated_at)
select 'IN','India','IN','IND','356',false,'ISO 3166-1 alpha-2 / alpha-3 / numeric country reference','2026-11-17'::date
where not exists (select 1 from public.krim_countries where upper(code)='IN');

insert into public.krim_country_operating_packs(jurisdiction_code,country_name) select upper(code),name from public.krim_countries on conflict(jurisdiction_code) do nothing;
with d(control_code,domain,title,service_scopes) as (values
('ENTITY_PRESENCE','entity','Entity form, foreign ownership and local presence',array['platform','marketplace']::text[]),
('BUSINESS_LICENSING','licensing','Business and sector licensing boundaries',array['platform','road','rail','ocean','air','warehouse','customs']::text[]),
('TRANSPORT_MODES','transport','Mode-specific operator permits and safety requirements',array['road','rail','ocean','air','multimodal']::text[]),
('TAX_INVOICING','tax','Tax registrations, invoicing and statutory reporting',array['platform','marketplace','payments','finance']::text[]),
('PAYMENTS_FX','payments','Payment collection, custody, settlement and FX',array['payments','finance','marketplace']::text[]),
('CUSTOMS_TRADE','customs','Customs, import/export and trade controls',array['ocean','air','customs','freight_forwarding']::text[]),
('CARGO_ADMISSIBILITY','cargo','Restricted goods and dangerous-goods admissibility',array['road','rail','ocean','air','warehouse','customs']::text[]),
('PRIVACY_DATA','privacy','Privacy, data residency and international transfers',array['platform','all_workspaces','ai']::text[]),
('CONSUMER_MARKETPLACE','consumer','Consumer protection, marketplace disclosures and complaints',array['platform','marketplace','customer']::text[]),
('WORKFORCE_SAFETY','workforce','Employment, contractor and occupational safety',array['platform','road','rail','ocean','air','warehouse']::text[]),
('INSURANCE_LIABILITY','insurance','Compulsory insurance, cargo liability and claims',array['road','rail','ocean','air','warehouse','marketplace']::text[]),
('CONTRACTS_DISPUTES','contracts','Contract enforceability, signatures and dispute resolution',array['platform','marketplace','all_services']::text[]),
('COMPETITION_INTEGRITY','competition','Competition, anti-bribery and marketplace integrity',array['platform','marketplace','all_services']::text[]),
('CYBER_RESILIENCE','cybersecurity','Cybersecurity, incident reporting and continuity',array['platform','all_workspaces','ai']::text[]),
('ENVIRONMENT_FACILITIES','environment','Environmental, facility, fire and hazardous-storage controls',array['road','rail','ocean','air','warehouse']::text[]),
('LANGUAGE_ACCESSIBILITY','accessibility','Mandatory language, accessibility and record formats',array['platform','all_workspaces','customer']::text[]),
('LOCAL_OPERATIONS','operations','Local provider, facility, support and emergency readiness',array['all_services']::text[]),
('REGULATORY_MONITORING','regulatory_change','Official-source monitoring and regulatory change ownership',array['platform','all_services']::text[]))
insert into public.krim_country_pack_controls(pack_id,control_code,domain,title,service_scopes) select p.id,d.control_code,d.domain,d.title,d.service_scopes from public.krim_country_operating_packs p cross join d on conflict(pack_id,control_code) do nothing;

