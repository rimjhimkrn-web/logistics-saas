do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('private.krim_customs_document_review(bigint,text,text,bigint)'::regprocedure);
 v_old:=$old$ v_path text; v_mime text; v_size bigint; v_issued date; v_expires date;$old$;
 v_new:=$new$ v_path text; v_mime text; v_size bigint; v_issued date; v_expires date; v_submitter_org bigint; v_issuing_country bigint; v_customs_country bigint;$new$;
 if position(v_old in v_def)=0 then raise exception 'Customs review declaration anchor not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=$old$        d.storage_path,d.mime_type,d.file_size,d.issued_at,d.expires_at
 INTO v_record,v_shipment,v_submitter,v_status,v_customer,v_path,v_mime,v_size,v_issued,v_expires
 FROM public.krim_customs_document_submissions d
 JOIN public.krim_shipments s ON s.id=d.shipment_id
 WHERE d.id=p_submission_id FOR UPDATE OF d;$old$;
 v_new:=$new$        d.storage_path,d.mime_type,d.file_size,d.issued_at,d.expires_at,
        d.submitted_by_organization_id,d.issuing_country_id,c.country_id
 INTO v_record,v_shipment,v_submitter,v_status,v_customer,v_path,v_mime,v_size,v_issued,v_expires,
      v_submitter_org,v_issuing_country,v_customs_country
 FROM public.krim_customs_document_submissions d
 JOIN public.krim_shipments s ON s.id=d.shipment_id
 JOIN public.krim_shipment_customs c ON c.id=d.customs_record_id AND c.shipment_id=d.shipment_id
 WHERE d.id=p_submission_id FOR UPDATE OF d;$new$;
 if position(v_old in v_def)=0 then raise exception 'Customs review evidence lookup anchor not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=$old$ IF p_decision='verified' THEN
  IF v_issued IS NOT NULL AND v_issued>current_date THEN RAISE EXCEPTION 'A future-issued customs document cannot be verified'; END IF;$old$;
 v_new:=$new$ IF p_decision='verified' THEN
  IF v_broker IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.krim_organizations o
   WHERE o.id=v_broker AND o.status='active' AND o.organization_type='customs'
  ) THEN RAISE EXCEPTION 'An active accepted customs broker is required to verify this document'; END IF;
  IF NOT EXISTS(
   SELECT 1 FROM public.krim_customs_broker_licenses l
   WHERE l.organization_id=v_broker AND l.country_id=v_customs_country AND l.status='approved'
    AND (l.valid_from IS NULL OR l.valid_from<=current_date)
    AND (l.valid_until IS NULL OR l.valid_until>=current_date)
  ) THEN RAISE EXCEPTION 'A current approved customs broker licence for this jurisdiction is required'; END IF;
  IF v_issuing_country IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.krim_countries c WHERE c.id=v_issuing_country AND c.is_active
  ) THEN RAISE EXCEPTION 'The document issuing jurisdiction is inactive'; END IF;
  IF v_issued IS NOT NULL AND v_issued>current_date THEN RAISE EXCEPTION 'A future-issued customs document cannot be verified'; END IF;$new$;
 if position(v_old in v_def)=0 then raise exception 'Customs review verification precondition anchor not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;

 v_def:=pg_get_functiondef('private.krim_customs_broker_license_review(bigint,text,text)'::regprocedure);
 v_old:=$old$ if v_status<>'pending_review' then raise exception 'License is not awaiting review'; end if;$old$;
 v_new:=$new$ if v_status<>'pending_review' then raise exception 'License is not awaiting review'; end if;
 if v_submitter=v_user then raise exception 'Licence submitter cannot independently review their own customs broker licence evidence'; end if;$new$;
 if position(v_old in v_def)=0 then raise exception 'Customs broker licence review state guard changed'; end if;
 execute replace(v_def,v_old,v_new);
end;
$migration$;
