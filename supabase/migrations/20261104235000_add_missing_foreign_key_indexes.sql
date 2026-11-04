-- Add covering indexes for foreign keys identified by the Supabase performance advisor.
create index if not exists krim_corridor_controls_source_id_idx on public.krim_corridor_compliance_controls(source_id);
create index if not exists krim_corridor_events_control_id_idx on public.krim_corridor_compliance_events(control_id);
create index if not exists krim_corridor_legs_country_id_idx on public.krim_corridor_compliance_legs(country_id);
create index if not exists krim_country_pack_control_events_control_id_idx on public.krim_country_pack_control_events(control_id);
create index if not exists krim_country_pack_controls_source_id_idx on public.krim_country_pack_controls(source_id);
create index if not exists krim_country_pack_events_pack_id_idx on public.krim_country_pack_events(pack_id);
create index if not exists krim_market_activation_events_market_id_idx on public.krim_market_activation_events(market_id);
create index if not exists krim_market_readiness_events_assessment_id_idx on public.krim_market_readiness_events(assessment_id);
create index if not exists krim_market_regulatory_source_events_source_id_idx on public.krim_market_regulatory_source_events(source_id);
create index if not exists krim_driver_invitations_accepted_by_idx on private.krim_driver_invitations(accepted_by);
create index if not exists krim_driver_invitations_invited_by_idx on private.krim_driver_invitations(invited_by);
create index if not exists krim_driver_verification_documents_organization_id_idx on public.krim_driver_verification_documents(organization_id);