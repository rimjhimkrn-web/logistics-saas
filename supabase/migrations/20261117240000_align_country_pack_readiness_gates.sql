-- Align dashboard and market-activation readiness counts with the
-- independent evidence rules enforced by country-pack approval.
-- This migration deliberately fails closed if the expected source definition
-- has drifted; it must not silently leave a partially patched readiness gate.

do $migration$
declare
  v_def text;
  v_new text;
  v_old_lateral text;
  v_new_lateral text;
  v_old_pack_source text;
  v_new_pack_source text;
  v_old_req_source text;
  v_new_req_source text;
begin
  v_old_lateral := $old$
left join lateral(select count(*) total_n,count(*) filter(where c.review_status='approved' and c.applicability in('yes','no','conditional') and c.source_id is not null and nullif(btrim(c.evidence_reference),'') is not null and nullif(btrim(c.reviewer_note),'') is not null and (c.expires_at is null or c.expires_at>now())) approved_n from public.krim_country_pack_controls c where c.pack_id=p.id and c.mandatory) x on true;
$old$;
  v_new_lateral := $new$
left join lateral (
    select count(*) total_n,
      count(*) filter (
        where c.review_status='approved'
          and c.applicability in ('yes','no','conditional')
          and c.source_id is not null
          and nullif(btrim(c.evidence_reference),'') is not null
          and nullif(btrim(c.reviewer_note),'') is not null
          and c.reviewed_by is not null
          and (c.expires_at is null or c.expires_at>now())
          and s.id is not null
          and s.jurisdiction_code in (p.jurisdiction_code,'*')
          and s.review_status in ('source_checked','legal_reviewed')
          and (s.effective_from is null or s.effective_from<=current_date)
          and (s.effective_until is null or s.effective_until>=current_date)
          and s.created_by is not null and s.reviewed_by is not null
          and s.created_by<>s.reviewed_by
          and c.reviewed_by<>s.created_by
          and c.reviewed_by<>s.reviewed_by
      ) approved_n
    from public.krim_country_pack_controls c
    left join public.krim_market_regulatory_sources s on s.id=c.source_id
    where c.pack_id=p.id and c.mandatory
  ) x on true;
$new$;

  v_def := pg_get_functiondef('public.krim_admin_list_country_packs()'::regprocedure);
  if position(v_new_lateral in v_def)=0 then
    if position(v_old_lateral in v_def)=0 then
      raise exception 'Country pack list RPC definition drifted; refusing unsafe patch';
    end if;
    v_new := replace(v_def,v_old_lateral,v_new_lateral);
    execute v_new;
  end if;

  v_old_pack_source := $old$
and s.review_status in ('source_checked','legal_reviewed')
 and (c.expires_at is null or c.expires_at>now());
$old$;
  v_new_pack_source := $new$
and s.jurisdiction_code in (v_country_code,'*')
 and s.review_status in ('source_checked','legal_reviewed')
 and (s.effective_from is null or s.effective_from<=current_date)
 and (s.effective_until is null or s.effective_until>=current_date)
 and s.created_by is not null and s.reviewed_by is not null
 and s.created_by<>s.reviewed_by
 and c.reviewed_by is not null
 and c.reviewed_by<>s.created_by
 and c.reviewed_by<>s.reviewed_by
 and (c.expires_at is null or c.expires_at>now());
$new$;

  v_def := pg_get_functiondef('public.krim_internal_market_activation_gate(bigint)'::regprocedure);
  v_new := replace(v_def,'select upper(code) into v_country_code','select upper(iso2_code) into v_country_code');
  if position(v_new_pack_source in v_new)=0 then
    if position(v_old_pack_source in v_new)=0 then
      raise exception 'Market gate country-pack source clause drifted; refusing unsafe patch';
    end if;
    v_new := replace(v_new,v_old_pack_source,v_new_pack_source);
  end if;

  v_old_req_source := $old$
and s.review_status in ('source_checked','legal_reviewed')
        and (
$old$;
  v_new_req_source := $new$
and s.review_status in ('source_checked','legal_reviewed')
        and (s.effective_from is null or s.effective_from<=current_date)
        and (s.effective_until is null or s.effective_until>=current_date)
        and s.created_by is not null and s.reviewed_by is not null
        and s.created_by<>s.reviewed_by
        and (
$new$;
  if position(v_new_req_source in v_new)=0 then
    if position(v_old_req_source in v_new)=0 then
      raise exception 'Market requirement source clause drifted; refusing unsafe patch';
    end if;
    v_new := replace(v_new,v_old_req_source,v_new_req_source);
  end if;

  if v_new=v_def then
    -- Existing definition already satisfies this migration.
    null;
  else
    execute v_new;
  end if;
end;
$migration$;

revoke all on function public.krim_internal_market_activation_gate(bigint) from public,anon,authenticated;
grant execute on function public.krim_internal_market_activation_gate(bigint) to service_role;
