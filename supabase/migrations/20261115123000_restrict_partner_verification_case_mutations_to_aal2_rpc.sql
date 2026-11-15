-- Keep partner verification case decisions inside the audited AAL2 review RPC.
-- Direct table writes bypass the RPC's MFA, validation, and audit-event controls.
drop policy if exists "KRIM platform admin delete partner verification"
  on public.krim_partner_verification_cases;
drop policy if exists "KRIM platform admin insert partner verification"
  on public.krim_partner_verification_cases;
drop policy if exists "KRIM platform admin update partner verification"
  on public.krim_partner_verification_cases;

revoke insert, update, delete
  on table public.krim_partner_verification_cases
  from authenticated;

comment on table public.krim_partner_verification_cases is
  'Partner verification cases. Authenticated users may read only through scoped RLS; all case mutations must use audited AAL2 platform-admin RPCs.';
