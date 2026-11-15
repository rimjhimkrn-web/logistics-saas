CREATE OR REPLACE FUNCTION private.krim_customs_broker_license_review(p_license_id bigint, p_decision text, p_note text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
 v_user uuid:=auth.uid();
 v_org bigint; v_country bigint; v_from date; v_until date; v_status text;
 v_path text; v_mime text; v_size bigint; v_submitter uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
 IF coalesce(auth.jwt()->>'aal','aal1')<>'aal2' THEN RAISE EXCEPTION 'Multi-factor authentication required'; END IF;
 IF NOT private.krim_has_permission(v_user,1,'admin.platform') THEN RAISE EXCEPTION 'Platform admin permission required'; END IF;
 IF p_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid review decision'; END IF;
 IF length(trim(coalesce(p_note,'')))<20 THEN RAISE EXCEPTION 'Independent verification note must contain at least 20 characters'; END IF;
 SELECT organization_id,country_id,valid_from,valid_until,status,evidence_path,evidence_mime_type,evidence_file_size,submitted_by
 INTO v_org,v_country,v_from,v_until,v_status,v_path,v_mime,v_size,v_submitter
 FROM public.krim_customs_broker_licenses WHERE id=p_license_id FOR UPDATE;
 IF v_org IS NULL THEN RAISE EXCEPTION 'License record not found'; END IF;
 IF v_status<>'pending_review' THEN RAISE EXCEPTION 'License is not awaiting review'; END IF;
 IF v_submitter IS NULL OR v_submitter=v_user THEN RAISE EXCEPTION 'Independent licence review required; the submitter cannot approve or reject their own evidence'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organizations o WHERE o.id=v_org AND o.organization_type='customs' AND o.status='active') THEN RAISE EXCEPTION 'Customs broker organization is no longer active'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_countries c WHERE c.id=v_country AND c.is_active) THEN RAISE EXCEPTION 'Customs jurisdiction is no longer active'; END IF;
 IF p_decision='approved' THEN
  IF v_from IS NOT NULL AND v_from>current_date THEN RAISE EXCEPTION 'Future-effective licence cannot be approved before its effective date'; END IF;
  IF v_until IS NOT NULL AND v_until<current_date THEN RAISE EXCEPTION 'Expired licence cannot be approved'; END IF;
  IF v_path IS NULL OR v_mime NOT IN ('application/pdf','image/jpeg','image/png') OR v_size IS NULL OR v_size<1 OR v_size>10485760 THEN RAISE EXCEPTION 'Valid licence evidence metadata is required for approval'; END IF;
  IF split_part(v_path,'/',1)<>'customs' OR split_part(v_path,'/',2)<>v_org::text OR split_part(v_path,'/',3)<>v_submitter::text OR cardinality(string_to_array(v_path,'/'))<>4 THEN
   RAISE EXCEPTION 'Licence evidence path does not match the original submitting organization and user';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='krim-partner-verification' AND o.name=v_path AND o.owner=v_submitter
    AND o.metadata->>'mimetype'=v_mime AND (o.metadata->>'size') ~ '^[0-9]+$' AND (o.metadata->>'size')::bigint=v_size) THEN
   RAISE EXCEPTION 'Original private licence evidence is missing or no longer matches the submitted metadata';
  END IF;
 END IF;
 UPDATE public.krim_customs_broker_licenses SET status=p_decision,reviewed_by=v_user,reviewed_at=now(),review_note=left(trim(p_note),2000),updated_at=now() WHERE id=p_license_id;
 INSERT INTO public.krim_customs_broker_license_events(license_id,organization_id,event_type,actor_user_id,event_note)
 VALUES(p_license_id,v_org,p_decision,v_user,left(trim(p_note),2000));
 RETURN true;
END;
$function$;

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
 v_path text; v_mime text; v_size bigint; v_issued date; v_expires date; v_submitter_org bigint;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
 IF coalesce(auth.jwt()->>'aal','aal1')<>'aal2' THEN RAISE EXCEPTION 'Multi-factor authentication required'; END IF;
 IF length(trim(coalesce(p_note,'')))<10 THEN RAISE EXCEPTION 'A meaningful review note of at least 10 characters is required'; END IF;
 IF p_decision NOT IN ('verified','rejected') THEN RAISE EXCEPTION 'Invalid document review decision'; END IF;
 SELECT d.customs_record_id,d.shipment_id,d.submitted_by_user_id,d.status,s.customer_organization_id,
        d.storage_path,d.mime_type,d.file_size,d.issued_at,d.expires_at,d.submitted_by_organization_id
 INTO v_record,v_shipment,v_submitter,v_status,v_customer,v_path,v_mime,v_size,v_issued,v_expires,v_submitter_org
 FROM public.krim_customs_document_submissions d
 JOIN public.krim_shipments s ON s.id=d.shipment_id
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
  IF v_issued IS NOT NULL AND v_issued>current_date THEN RAISE EXCEPTION 'A future-issued customs document cannot be verified'; END IF;
  IF v_expires IS NOT NULL AND v_expires<current_date THEN RAISE EXCEPTION 'An expired customs document cannot be verified'; END IF;
  IF v_path IS NULL OR v_mime NOT IN ('application/pdf','image/jpeg','image/png') OR v_size IS NULL OR v_size<1 OR v_size>10485760 THEN
   RAISE EXCEPTION 'Valid private customs document evidence metadata is required';
  END IF;
  IF split_part(v_path,'/',1)<>'customs-docs' OR split_part(v_path,'/',2)<>v_shipment::text
     OR split_part(v_path,'/',3)<>v_submitter_org::text OR split_part(v_path,'/',4)<>v_submitter::text
     OR cardinality(string_to_array(v_path,'/'))<>5 THEN
   RAISE EXCEPTION 'Customs document evidence path does not match its shipment, organization and submitter';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='krim-partner-verification' AND o.name=v_path AND o.owner=v_submitter
    AND o.metadata->>'mimetype'=v_mime AND (o.metadata->>'size') ~ '^[0-9]+$' AND (o.metadata->>'size')::bigint=v_size) THEN
   RAISE EXCEPTION 'Original private customs document is missing or no longer matches its submitted metadata';
  END IF;
 END IF;
 UPDATE public.krim_customs_document_submissions
 SET status=p_decision,reviewed_by=v_user,reviewed_by_organization_id=v_actor_org,reviewed_at=now(),review_note=left(trim(p_note),2000),updated_at=now()
 WHERE id=p_submission_id;
 INSERT INTO public.krim_customs_document_events(submission_id,customs_record_id,shipment_id,event_type,actor_user_id,actor_organization_id,event_note)
 VALUES(p_submission_id,v_record,v_shipment,p_decision,v_user,v_actor_org,left(trim(p_note),2000));
 RETURN true;
END;
$function$;
