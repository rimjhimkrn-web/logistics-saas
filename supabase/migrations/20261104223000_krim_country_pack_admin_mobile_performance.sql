create or replace function public.krim_admin_list_country_packs()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
 if v_user is null or coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then raise exception using errcode='42501',message='AAL2 platform administrator access required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('pack_id',p.id,'jurisdiction_code',p.jurisdiction_code,'country_name',p.country_name,'pack_version',p.pack_version,'pack_status',p.pack_status,'legal_owner',p.legal_owner,'next_review_at',p.next_review_at,'mandatory_controls',coalesce(x.total_n,0),'approved_controls',coalesce(x.approved_n,0)) order by p.country_name),'[]'::jsonb) into v_result
 from public.krim_country_operating_packs p left join lateral(select count(*) total_n,count(*) filter(where c.review_status='approved' and c.applicability in('yes','no','conditional') and c.source_id is not null and nullif(btrim(c.evidence_reference),'') is not null and nullif(btrim(c.reviewer_note),'') is not null and (c.expires_at is null or c.expires_at>now())) approved_n from public.krim_country_pack_controls c where c.pack_id=p.id and c.mandatory) x on true;
 return jsonb_build_object('packs',v_result);
end $$;
create or replace function public.krim_admin_get_country_pack(p_pack_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_pack public.krim_country_operating_packs%rowtype; v_controls jsonb;
begin
 if v_user is null or coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.krim_has_permission(v_user,1::bigint,'admin.platform') then raise exception using errcode='42501',message='AAL2 platform administrator access required'; end if;
 select * into v_pack from public.krim_country_operating_packs where id=p_pack_id; if not found then raise exception using errcode='P0002',message='Country pack not found'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('control_id',c.id,'control_code',c.control_code,'domain',c.domain,'title',c.title,'service_scopes',c.service_scopes,'mandatory',c.mandatory,'applicability',c.applicability,'review_status',c.review_status,'source_id',c.source_id,'evidence_reference',c.evidence_reference,'reviewer_note',c.reviewer_note,'reviewed_at',c.reviewed_at,'expires_at',c.expires_at) order by c.control_code),'[]'::jsonb) into v_controls from public.krim_country_pack_controls c where c.pack_id=p_pack_id;
 return jsonb_build_object('pack_id',v_pack.id,'jurisdiction_code',v_pack.jurisdiction_code,'country_name',v_pack.country_name,'pack_version',v_pack.pack_version,'pack_status',v_pack.pack_status,'controls',v_controls);
end $$;
revoke all on function public.krim_admin_get_country_pack(bigint) from public,anon;
grant execute on function public.krim_admin_get_country_pack(bigint) to authenticated;