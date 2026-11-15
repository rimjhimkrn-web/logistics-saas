do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.krim_admin_review_partner_capability(bigint,text,text)'::regprocedure);
  v_old := $old$ update public.krim_partner_capabilities set verification_status=case when v_decision='approved' then 'verified' else 'rejected' end,$old$;
  v_new := $new$ if v_decision='approved' and exists(
   select 1 from public.krim_partner_capabilities c
   where c.id=p_capability_id and c.hazardous_goods_capable is true
  ) then
   raise exception using errcode='23514',message='Hazardous-goods capability cannot be approved through the standard workflow; jurisdiction-specific safety evidence and authorization controls are required';
  end if;
  if v_decision='approved' and exists(
   select 1 from public.krim_partner_capabilities c
   where c.id=p_capability_id and c.refrigerated is true
  ) then
   raise exception using errcode='23514',message='Cold-chain capability cannot be approved until temperature-range, equipment and calibration evidence controls are available';
  end if;
  if v_decision='approved' and exists(
   select 1 from public.krim_partner_capabilities c
   where c.id=p_capability_id
     and (
       c.effective_from is null
       or (c.effective_until is not null and (c.effective_until<=now() or c.effective_until<=c.effective_from))
       or (c.max_weight_kg is not null and (c.max_weight_kg<=0 or c.max_weight_kg>100000000 or c.max_weight_kg::text in ('NaN','Infinity','-Infinity')))
     )
  ) then
   raise exception using errcode='23514',message='Capability validity dates or maximum weight are invalid; correct the evidence-backed scope before approval';
  end if;
  update public.krim_partner_capabilities set verification_status=case when v_decision='approved' then 'verified' else 'rejected' end,$new$;
  if position(v_old in v_def)=0 then
    raise exception 'Partner capability review definition changed; aborting specialist capability guard';
  end if;
  execute replace(v_def,v_old,v_new);
end;
$migration$;
