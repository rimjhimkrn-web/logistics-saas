CREATE OR REPLACE FUNCTION private.krim_customs_document_review(p_submission_id bigint, p_decision text, p_note text, p_actor_organization_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_user uuid:=auth.uid();
 v_record bigint; v_shipment bigint; v_submitter uuid; v_status text; v_broker bigint; v_customer bigint;
 v_is_admin boolean; v_actor_org bigint;
 v_path text; v_mime text; v_size bigint; v_issued date; v_expires date;
 v_submitter_org bigint; v_issuing_country bigint; v_customs_country bigint;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
 IF coalesce(auth.jwt()->>'aal','aal1')<>'aal2' THEN RAISE EXCEPTION 'Multi-factor authentication required'; END IF;
 IF length(trim(coalesce(p_note,'')))<10 THEN RAISE EXCEPTION 'A meaningful review note of at least 10 characters is required'; END IF;
 IF p_decision NOT IN ('verified','rejected') THEN RAISE EXCEPTION 'Invalid document review decision'; END IF;
 SELECT d.customs_record_id,d.shipment_id,d.submitted_by_user_id,d.status,s.customer_organization_id,
        d.storage_path,d.mime_type,d.file_size,d.issued_at,d.expires_at,
        d.submitted_by_organization_id,d.issuing_country_id,c.country_id
 INTO v_record,v_shipment,v_submitter,v_status,v_customer,v_path,v_mime,v_size,v_issued,v_expires,
      v_submitter_org,v_issuing_country,v_customs_country
 FROM public.krim_customs_document_submissions d
 JOIN public.krim_shipments s ON s.id=d.shipment_id
 JOIN public.krim_shipment_customs c ON c.id=d.customs_record_id AND c.shipment_id=d.shipment_id
 WHERE d.id=p_submission_id FOR UPDATE OF d;
 IF v_record IS NULL THEN RAISE EXCEPTION 'Document submission not found'; END IF;
 IF v_submitter=v_user THEN RAISE EXCEPTION 'Submitter cannot review their own document'; END IF;
 IF v_status<>'pending_review' THEN RAISE EXCEPTION 'Document is not awaiting review'; END IF;
 SELECT a.broker_organization_id INTO v_broker FROM public.krim_customs_broker_assignments a
 WHERE a.customs_record_id=v_record AND a.shipment_id=v_shipment AND a.assignment_status='accepted'
 ORDER BY a.accepted_at DESC LIMIT 1;
 v_is_admin:=private.krim_has_permission(v_user,1,'admin.platform');
 IF p_actor_organization_id=v_broker AND private.krim_has_permission(v_user,v_broker,'compliance.view') THEN
  v_actor_org:=v_broker;
 ELSIF p_decision='rejected' AND p_actor_organization_id=v_customer AND private.krim_has_permission(v_user,v_customer,'shipment.update') THEN
  v_actor_org:=v_customer;
 ELSIF p_decision='rejected' AND v_is_admin THEN
  v_actor_org:=1;
 ELSE
  RAISE EXCEPTION 'Review requires the accepted broker, customer rejection authority, or AAL2 platform admin';
 END IF;
 IF p_decision='verified' THEN
  IF v_broker IS NULL OR NOT EXISTS(SELECT 1 FROM public.krim_organizations o WHERE o.id=v_broker AND o.status='active' AND o.organization_type='customs') THEN
   RAISE EXCEPTION 'An active accepted customs broker is required to verify this document';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.krim_customs_broker_licenses l WHERE l.organization_id=v_broker AND l.country_id=v_customs_country
    AND l.status='approved' AND (l.valid_from IS NULL OR l.valid_from<=current_date) AND (l.valid_until IS NULL OR l.valid_until>=current_date)) THEN
   RAISE EXCEPTION 'A current approved customs broker licence for this jurisdiction is required';
  END IF;
  IF v_issuing_country IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.krim_countries c WHERE c.id=v_issuing_country AND c.is_active) THEN
   RAISE EXCEPTION 'The document issuing jurisdiction is inactive';
  END IF;
  IF v_issued IS NOT NULL AND v_issued>current_date THEN RAISE EXCEPTION 'A future-issued customs document cannot be verified'; END IF;
  IF v_expires IS NOT NULL AND v_expires<current_date THEN RAISE EXCEPTION 'An expired customs document cannot be verified'; END IF;
  IF v_path IS NULL OR v_mime NOT IN ('application/pdf','image/jpeg','image/png') OR v_size IS NULL OR v_size<1 OR v_size>10485760 THEN
   RAISE EXCEPTION 'Valid private customs document evidence metadata is required';
  END IF;
  IF split_part(v_path,'/',1)<>'customs-docs' OR split_part(v_path,'/',2)<>v_shipment::text OR split_part(v_path,'/',3)<>v_submitter_org::text
     OR split_part(v_path,'/',4)<>v_submitter::text OR cardinality(string_to_array(v_path,'/'))<>5 THEN
   RAISE EXCEPTION 'Customs document evidence path does not match its shipment, organization and submitter';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='krim-partner-verification' AND o.name=v_path AND o.owner=v_submitter
    AND o.metadata->>'mimetype'=v_mime AND (o.metadata->>'size') ~ '^[0-9]+$' AND (o.metadata->>'size')::bigint=v_size) THEN
   RAISE EXCEPTION 'Original private customs document is missing or no longer matches its submitted metadata';
  END IF;
 END IF;
 UPDATE public.krim_customs_document_submissions SET status=p_decision,reviewed_by=v_user,reviewed_by_organization_id=v_actor_org,
  reviewed_at=now(),review_note=left(trim(p_note),2000),updated_at=now() WHERE id=p_submission_id;
 INSERT INTO public.krim_customs_document_events(submission_id,customs_record_id,shipment_id,event_type,actor_user_id,actor_organization_id,event_note)
 VALUES(p_submission_id,v_record,v_shipment,p_decision,v_user,v_actor_org,left(trim(p_note),2000));
 RETURN true;
END;
$function$;
