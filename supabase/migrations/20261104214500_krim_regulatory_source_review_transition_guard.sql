create or replace function public.krim_admin_review_regulatory_source(p_source_id bigint,p_new_status text,p_rationale text,p_evidence_reference text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_source public.krim_market_regulatory_sources%rowtype; v_old text;
begin
 if v_user is null then raise exception using errcode='28000',message='Authentication required'; end if;
 if coalesce(auth.jwt()->>'aal','aal1')<>'aal2' then raise exception using errcode='42501',message='AAL2 required'; end if;
 if not private.krim_has_permission(v_user,1::bigint,'admin.platform') then raise exception using errcode='42501',message='Platform administrator permission required'; end if;
 if p_new_status is null or p_new_status not in ('source_checked','legal_review_pending','legal_reviewed','rejected','retired') or p_rationale is null or length(btrim(p_rationale))<20 then
  raise exception using errcode='22023',message='Valid review status and rationale of at least 20 characters required'; end if;
 select * into v_source from public.krim_market_regulatory_sources where id=p_source_id for update;
 if not found then raise exception using errcode='P0002',message='Source version not found'; end if;
 v_old:=v_source.review_status;
 if p_new_status='source_checked' and (v_source.source_kind not in ('official_primary','official_secondary') or v_source.sha256 is null or v_source.source_url is null) then
  raise exception using errcode='22023',message='Source check requires official source URL and recorded SHA-256 snapshot'; end if;
 if p_new_status='legal_review_pending' and not (v_old in ('source_checked','legal_review_pending') or (v_old='pending' and v_source.source_kind in ('qualified_legal_opinion','qualified_tax_opinion'))) then
  raise exception using errcode='22023',message='Verify official source first, or register a qualified legal/tax opinion'; end if;
 if p_new_status='legal_reviewed' and (v_source.source_kind not in ('qualified_legal_opinion','qualified_tax_opinion') or v_old not in ('pending','legal_review_pending') or nullif(btrim(p_evidence_reference),'') is null) then
  raise exception using errcode='22023',message='Legal/tax reviewed status requires a qualified opinion record and evidence reference'; end if;
 update public.krim_market_regulatory_sources set review_status=p_new_status,reviewed_by=v_user,reviewed_at=now(),
 evidence_reference=coalesce(nullif(btrim(p_evidence_reference),''),evidence_reference),reviewer_notes=left(coalesce(reviewer_notes||E'\n','')||btrim(p_rationale),4000) where id=p_source_id;
 insert into public.krim_market_regulatory_source_events(source_id,actor_user_id,previous_status,new_status,rationale,evidence_reference)
 values(p_source_id,v_user,v_old,p_new_status,btrim(p_rationale),nullif(btrim(p_evidence_reference),''));
 insert into public.krim_audit_events(actor_user_id,event_type,entity_type,entity_id,source,metadata,previous_state,new_state)
 values(v_user,'market_readiness.source_reviewed','krim_market_regulatory_sources',p_source_id::text,'market_readiness_console',
 jsonb_build_object('rationale',btrim(p_rationale),'evidence_reference',p_evidence_reference),
 jsonb_build_object('review_status',v_old),jsonb_build_object('review_status',p_new_status,'reviewed_at',now()));
 return jsonb_build_object('success',true,'source_id',p_source_id,'previous_status',v_old,'review_status',p_new_status);
end; $$;
revoke all on function public.krim_admin_review_regulatory_source(bigint,text,text,text) from public,anon;
grant execute on function public.krim_admin_review_regulatory_source(bigint,text,text,text) to authenticated;