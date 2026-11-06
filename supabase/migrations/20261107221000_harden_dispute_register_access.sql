-- Dispute records are sensitive financial/customer data. Keep party-scoped SELECT policies,
-- force RLS even for table owners, and remove inherited anonymous table access.
alter table public.krim_disputes force row level security;
alter table public.krim_dispute_cases force row level security;
alter table public.krim_dispute_decisions force row level security;
alter table public.krim_dispute_evidence_links force row level security;
alter table public.krim_dispute_investigations force row level security;
alter table public.krim_dispute_appeals force row level security;
revoke all on table public.krim_disputes,public.krim_dispute_cases,public.krim_dispute_decisions,
 public.krim_dispute_evidence_links,public.krim_dispute_investigations,public.krim_dispute_appeals
 from public,anon,authenticated;
grant select on table public.krim_disputes,public.krim_dispute_cases,public.krim_dispute_decisions,
 public.krim_dispute_evidence_links,public.krim_dispute_investigations,public.krim_dispute_appeals
 to authenticated;
revoke all on sequence public.krim_disputes_id_seq,public.krim_dispute_cases_id_seq,
 public.krim_dispute_decisions_id_seq,public.krim_dispute_evidence_links_id_seq,
 public.krim_dispute_investigations_id_seq,public.krim_dispute_appeals_id_seq
 from public,anon,authenticated;
