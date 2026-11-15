CREATE OR REPLACE FUNCTION public.krim_internal_evaluate_shipment_readiness(p_shipment_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_ship public.krim_shipments%rowtype;
  v_pay text := 'missing';
  v_comp text := 'pending';
  v_doc text := 'clear';
  v_partner text := 'missing';
  v_customs text := 'not_required';
  v_status text;
  v_reasons jsonb := '[]'::jsonb;
  v_quote_status text;
  v_comp_result jsonb;
  v_doc_result jsonb;
begin
  select * into v_ship
  from public.krim_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment_not_found';
  end if;

  select q.status into v_quote_status
  from public.krim_quotes q
  where q.shipment_id = p_shipment_id
  order by q.id desc
  limit 1;

  -- KRIM's current partner-direct launch model does not collect freight funds.
  -- The customer/provider payment is outside KRIM's ledger and is not a KRIM-paid status.
  if v_ship.status in ('draft','requested') then
    v_pay := 'not_required';
  else
    v_pay := 'partner_direct';
  end if;

  v_comp_result := public.krim_internal_evaluate_shipment_compliance_gate(p_shipment_id);
  v_comp := coalesce(v_comp_result->>'status','pending');
  if v_comp <> 'clear' then
    v_reasons := v_reasons || pg_catalog.jsonb_build_array('compliance_' || v_comp);
  end if;

  v_doc_result := public.krim_internal_evaluate_shipment_document_gate(p_shipment_id);
  v_doc := coalesce(v_doc_result->>'status','clear');
  if v_doc <> 'clear' then
    v_reasons := v_reasons || pg_catalog.jsonb_build_array('documents_' || v_doc);
  end if;

  if exists (
    select 1
    from public.krim_shipment_customs c
    where c.shipment_id = p_shipment_id
      and c.status not in ('cleared','cancelled')
  ) then
    v_customs := 'pending';
    v_reasons := v_reasons || pg_catalog.jsonb_build_array('customs_clearance_pending');
  elsif exists (
    select 1
    from public.krim_shipment_customs c
    where c.shipment_id = p_shipment_id
      and c.status = 'cleared'
  ) then
    v_customs := 'cleared';
  end if;

  if v_ship.status in ('draft','requested','quoted','confirmed') then
    v_partner := 'not_required';
  elsif exists (
    select 1
    from public.krim_shipment_partner_assignments a
    where a.shipment_id = p_shipment_id
      and a.status in ('accepted','active')
  ) then
    v_partner := 'assigned';
  else
    v_partner := 'missing';
    v_reasons := v_reasons || pg_catalog.jsonb_build_array('partner_assignment_missing');
  end if;

  if pg_catalog.jsonb_array_length(v_reasons) = 0 then
    v_status := 'ready';
  elsif v_comp in ('blocked','expired')
     or v_doc in ('blocked','expired')
     or v_pay in ('failed','missing')
     or v_customs = 'pending' then
    v_status := 'blocked';
  else
    v_status := 'review_required';
  end if;

  insert into public.krim_shipment_readiness_gates
    (shipment_id,status,payment_status,compliance_status,document_status,partner_status,blocking_reasons,checked_at,metadata)
  values
    (p_shipment_id,v_status,v_pay,v_comp,v_doc,v_partner,v_reasons,pg_catalog.now(),
     pg_catalog.jsonb_build_object('quote_status',v_quote_status,'customs_status',v_customs,
       'payment_collection_model','partner_direct','krim_freight_collection_required',false,
       'payment_evidence_sources',pg_catalog.jsonb_build_array()))
  on conflict(shipment_id) do update set
    status=excluded.status,
    payment_status=excluded.payment_status,
    compliance_status=excluded.compliance_status,
    document_status=excluded.document_status,
    partner_status=excluded.partner_status,
    blocking_reasons=excluded.blocking_reasons,
    checked_at=excluded.checked_at,
    metadata=excluded.metadata,
    updated_at=pg_catalog.now();

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'shipment_id',p_shipment_id,
    'status',v_status,
    'payment_status',v_pay,
    'payment_collection_model','partner_direct',
    'compliance_status',v_comp,
    'document_status',v_doc,
    'partner_status',v_partner,
    'customs_status',v_customs,
    'blocking_reasons',v_reasons
  );
end;
$function$

