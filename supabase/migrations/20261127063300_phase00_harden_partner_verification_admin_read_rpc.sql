-- Harden the remaining authenticated SECURITY DEFINER admin read RPC.
create or replace function public.krim_admin_list_partner_verification_cases()
returns table(
  case_id bigint, case_number text, verification_level text, case_status text,
  decision text, decision_reason text, submitted_at timestamptz,
  updated_at timestamptz, organization_id bigint, legal_name text,
  organization_type text, organization_status text, case_metadata jsonb,
  organization_metadata jsonb
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception using errcode='28000', message='Authentication required';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception using errcode='42501', message='Multi-factor authentication required';
  end if;
  if not private.krim_has_permission(auth.uid(), 1::bigint, 'admin.platform') then
    raise exception using errcode='42501', message='Platform administrator permission required';
  end if;

  return query
  select c.id, c.case_number, c.verification_level, c.status, c.decision,
         c.decision_reason, c.submitted_at, c.updated_at,
         o.id, o.legal_name, o.organization_type, o.status,
         c.metadata,
         coalesce(o.partner_metadata,'{}'::jsonb) || pg_catalog.jsonb_build_object(
           'account_mode',o.partner_account_mode,
           'partner_verification_status',o.partner_verification_status,
           'partner_compliance_status',o.partner_compliance_status,
           'partner_lifecycle_status',o.partner_lifecycle_status,
           'partner_review_notes',o.partner_review_notes,
           'partner_onboarding_status',o.partner_onboarding_status
         )
  from public.krim_partner_verification_cases c
  join public.krim_organizations o on o.id=c.organization_id
  order by case when c.status in ('open','in_review','pending_information') then 0 else 1 end,
           c.submitted_at desc nulls last
  limit 50;
end;
$function$;
