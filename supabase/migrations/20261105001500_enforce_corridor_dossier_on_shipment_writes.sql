-- Fail closed at the shipment write boundary unless an exact route and mode have a current approved corridor dossier.
create or replace function private.krim_enforce_corridor_compliance_on_shipment_write()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_corridor_id bigint; v_dossier_id bigint; v_mode text; v_controls_total integer; v_controls_valid integer; v_bad_country_packs integer;
begin
 if new.origin_location_id is null or new.destination_location_id is null then raise exception using errcode='23514',message='Shipment requires explicit origin and destination locations before corridor validation'; end if;
 if nullif(btrim(new.requested_transport_mode),'') is null then raise exception using errcode='23514',message='Shipment requires a requested transport mode before corridor validation'; end if;
 v_mode:=upper(btrim(new.requested_transport_mode));
 select c.id,d.id into v_corridor_id,v_dossier_id from public.krim_network_corridors c join public.krim_corridor_compliance_dossiers d on d.corridor_id=c.id
 where c.origin_location_id=new.origin_location_id and c.destination_location_id=new.destination_location_id and c.status='active' and d.dossier_status='approved_for_activation'
 and v_mode=any(select upper(x) from unnest(d.transport_mode_codes) x) order by c.id limit 1;
 if v_corridor_id is null or v_dossier_id is null then raise exception using errcode='23514',message='Shipment blocked: no active, approved, mode-matched corridor dossier exists for this exact origin and destination'; end if;
 select count(*),count(*) filter(where x.review_status='approved' and x.applicability in ('yes','no','conditional') and x.source_id is not null and nullif(btrim(x.evidence_reference),'') is not null and nullif(btrim(x.reviewer_note),'') is not null and (x.expires_at is null or x.expires_at>now()) and s.id is not null and s.review_status in ('source_checked','legal_reviewed') and (s.effective_until is null or s.effective_until>=current_date))
 into v_controls_total,v_controls_valid from public.krim_corridor_compliance_controls x left join public.krim_market_regulatory_sources s on s.id=x.source_id where x.dossier_id=v_dossier_id and x.mandatory;
 if v_controls_total=0 or v_controls_total<>v_controls_valid then raise exception using errcode='23514',message='Shipment blocked: one or more mandatory corridor controls are missing, expired, unapproved or lack a current reviewed source'; end if;
 select count(*) into v_bad_country_packs from public.krim_corridor_compliance_legs l join public.krim_countries co on co.id=l.country_id left join public.krim_country_operating_packs p on p.jurisdiction_code=upper(co.code)
 where l.dossier_id=v_dossier_id and (p.id is null or p.pack_status<>'approved' or exists(select 1 from public.krim_country_pack_controls pc left join public.krim_market_regulatory_sources ps on ps.id=pc.source_id where pc.pack_id=p.id and pc.mandatory and (pc.review_status<>'approved' or pc.applicability not in ('yes','no','conditional') or pc.source_id is null or nullif(btrim(pc.evidence_reference),'') is null or nullif(btrim(pc.reviewer_note),'') is null or (pc.expires_at is not null and pc.expires_at<=now()) or ps.id is null or ps.review_status not in ('source_checked','legal_reviewed') or (ps.effective_until is not null and ps.effective_until<current_date))));
 if v_bad_country_packs>0 then raise exception using errcode='23514',message='Shipment blocked: a corridor jurisdiction country pack is not approved or contains expired, unsupported mandatory controls'; end if;
 return new;
end $$;
drop trigger if exists krim_enforce_corridor_compliance_before_shipment_write on public.krim_shipments;
create trigger krim_enforce_corridor_compliance_before_shipment_write before insert or update of origin_location_id,destination_location_id,requested_transport_mode on public.krim_shipments for each row execute function private.krim_enforce_corridor_compliance_on_shipment_write();
revoke all on function private.krim_enforce_corridor_compliance_on_shipment_write() from public,anon,authenticated;