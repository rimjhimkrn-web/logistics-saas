-- Apply current compliance clearance to partner marketplace visibility.
grant execute on function private.krim_partner_compliance_is_current(bigint) to authenticated;
revoke execute on function private.krim_partner_compliance_is_current(bigint) from anon,public;

drop policy if exists krim_partner_compliance_current_opportunity_gate on public.krim_partner_opportunities;
create policy krim_partner_compliance_current_opportunity_gate
on public.krim_partner_opportunities as restrictive for select to authenticated
using (
 private.krim_has_permission((select auth.uid()),1::bigint,'admin.platform')
 or (customer_organization_id is not null and private.krim_has_organization_access((select auth.uid()),customer_organization_id))
 or (awarded_partner_organization_id is not null
     and private.krim_has_organization_access((select auth.uid()),awarded_partner_organization_id)
     and private.krim_partner_compliance_is_current(awarded_partner_organization_id))
 or (
  status='open' and exists(
   select 1 from public.krim_organization_members m
   join public.krim_organizations o on o.id=m.organization_id
   where m.user_id=(select auth.uid()) and m.status='active'
    and o.organization_type in ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator')
    and private.krim_partner_compliance_is_current(o.id)
    and exists(select 1 from public.krim_partner_capabilities pc
      where pc.organization_id=o.id and pc.active is true and pc.verification_status='verified'
       and (pc.effective_from is null or pc.effective_from<=now())
       and (pc.effective_until is null or pc.effective_until>now()))
    and private.krim_partner_capability_covers_shipment(o.id,krim_partner_opportunities.shipment_id)
  )
 )
);

drop policy if exists krim_partner_compliance_current_rate_card_gate on public.krim_rate_cards;
create policy krim_partner_compliance_current_rate_card_gate
on public.krim_rate_cards as restrictive for select to authenticated
using (
 (organization_id is null
  or not exists(select 1 from public.krim_organizations owner_org
    where owner_org.id=krim_rate_cards.organization_id
     and lower(coalesce(owner_org.organization_type_code,owner_org.organization_type,'')) in
      ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator'))
  or private.krim_partner_compliance_is_current(organization_id))
 and (partner_organization_id is null or private.krim_partner_compliance_is_current(partner_organization_id))
);

drop policy if exists krim_partner_compliance_current_rate_line_gate on public.krim_rate_lines;
create policy krim_partner_compliance_current_rate_line_gate
on public.krim_rate_lines as restrictive for select to authenticated
using (
 exists(select 1 from public.krim_rate_cards rc
  where rc.id=krim_rate_lines.rate_card_id
   and (rc.organization_id is null
    or not exists(select 1 from public.krim_organizations owner_org
      where owner_org.id=rc.organization_id
       and lower(coalesce(owner_org.organization_type_code,owner_org.organization_type,'')) in
        ('partner','carrier','forwarder','logistics_provider','warehouse','warehouse_operator'))
    or private.krim_partner_compliance_is_current(rc.organization_id))
   and (rc.partner_organization_id is null or private.krim_partner_compliance_is_current(rc.partner_organization_id)))
);