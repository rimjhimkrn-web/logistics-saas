create or replace function public.krim_internal_market_activation_gate(p_market_id bigint)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_market public.krim_markets%rowtype; v_country_id bigint; v_missing jsonb; v_missing_count integer;
 v_assessments integer; v_capabilities integer; v_locations integer; v_sources integer; v_expected integer; v_blockers jsonb;
begin
 select * into v_market from public.krim_markets where id=p_market_id;
 if not found then raise exception using errcode='P0002',message='Market not found'; end if;
 v_country_id:=v_market.country_id;
 select count(*) into v_locations from public.krim_locations l where l.country_id=v_country_id and l.is_active=true;
 select count(*) into v_capabilities from public.krim_partner_capabilities pc
 join public.krim_organizations o on o.id=pc.organization_id
 where pc.coverage_country_id=v_country_id and pc.active=true and pc.verification_status='verified'
 and (pc.effective_from is null or pc.effective_from<=now()) and (pc.effective_until is null or pc.effective_until>now())
 and o.status='active';
 select count(*) into v_expected from public.krim_market_readiness_requirements r
 where r.mandatory=true and r.jurisdiction_code in ('*',upper(v_market.code));
 select count(*) into v_assessments from public.krim_market_readiness_assessments a
 join public.krim_market_readiness_requirements r on r.id=a.requirement_id
 where a.market_id=p_market_id and r.mandatory=true and r.jurisdiction_code in ('*',upper(v_market.code))
 and a.status='approved' and nullif(btrim(a.evidence_reference),'') is not null
 and nullif(btrim(a.reviewer_note),'') is not null and (a.expires_at is null or a.expires_at>now());
 select count(*) into v_sources from public.krim_market_readiness_requirements r
 where r.mandatory=true and r.jurisdiction_code in ('*',upper(v_market.code))
 and exists(select 1 from public.krim_market_regulatory_sources s
  where s.requirement_id=r.id and s.jurisdiction_code in ('*',upper(v_market.code))
   and s.review_status in ('source_checked','legal_reviewed')
   and (r.category not in ('legal_structure','licensing','tax','payments','privacy','consumer_protection','customs','trade_controls','transport_safety','workforce','insurance')
    or exists(select 1 from public.krim_market_regulatory_sources op
      where op.requirement_id=r.id and op.jurisdiction_code in ('*',upper(v_market.code))
      and op.source_kind in ('qualified_legal_opinion','qualified_tax_opinion')
      and op.review_status='legal_reviewed' and nullif(btrim(op.evidence_reference),'') is not null)));
 select coalesce(jsonb_agg(jsonb_build_object('code',r.requirement_code,'category',r.category,'status',coalesce(a.status,'missing'),'evidence',a.evidence_reference,'expires_at',a.expires_at)), '[]'::jsonb)
 into v_missing
 from public.krim_market_readiness_requirements r
 left join public.krim_market_readiness_assessments a on a.requirement_id=r.id and a.market_id=p_market_id
 where r.mandatory=true and r.jurisdiction_code in ('*',upper(v_market.code))
 and (a.id is null or a.status<>'approved' or nullif(btrim(a.evidence_reference),'') is null or nullif(btrim(a.reviewer_note),'') is null or (a.expires_at is not null and a.expires_at<=now()));
 v_missing_count:=jsonb_array_length(v_missing);
 select coalesce(jsonb_agg(x),'[]'::jsonb) into v_blockers from (values
  (case when not (v_market.is_active and v_market.status='active') then 'Market catalogue is inactive' end),
  (case when v_locations=0 then 'No active service locations in this country' end),
  (case when v_capabilities=0 then 'No verified active partner capability in this country' end),
  (case when v_missing_count>0 then 'Mandatory assessments missing, unapproved, unsupported or expired' end),
  (case when v_sources<>v_expected then 'Mandatory requirements lack a source check or required qualified legal/tax opinion' end)
 ) as b(x) where x is not null;
 return jsonb_build_object(
  'market_id',p_market_id,'market_code',v_market.code,'catalogue_active',v_market.is_active and v_market.status='active',
  'market_locations',v_locations,'verified_active_partner_capabilities',v_capabilities,
  'mandatory_assessments_approved',v_assessments,'mandatory_requirements_expected',v_expected,
  'requirements_with_reviewed_sources',v_sources,'missing_assessments',v_missing,'missing_assessment_count',v_missing_count,
  'eligible',(v_market.is_active and v_market.status='active' and v_locations>0 and v_capabilities>0 and v_missing_count=0 and v_sources=v_expected),
  'blockers',v_blockers
 );
end; $$;
revoke all on function public.krim_internal_market_activation_gate(bigint) from public,anon,authenticated;