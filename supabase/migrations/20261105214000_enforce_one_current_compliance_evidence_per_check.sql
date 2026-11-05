create unique index if not exists krim_partner_compliance_evidence_one_current_per_check
 on public.krim_partner_compliance_evidence(organization_id,check_code)
 where is_current is true;