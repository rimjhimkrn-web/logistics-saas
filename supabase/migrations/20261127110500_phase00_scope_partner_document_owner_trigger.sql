drop trigger if exists trg_krim_partner_onboarding_document_owner on public.krim_organizations;
create trigger trg_krim_partner_onboarding_document_owner
before update of partner_metadata, partner_onboarding_status
on public.krim_organizations
for each row
when (
  new.partner_onboarding_status = 'submitted'
  and (
    old.partner_onboarding_status is distinct from 'submitted'
    or new.partner_metadata -> 'document_paths'
       is distinct from old.partner_metadata -> 'document_paths'
  )
)
execute function private.krim_assert_partner_onboarding_document_ownership();