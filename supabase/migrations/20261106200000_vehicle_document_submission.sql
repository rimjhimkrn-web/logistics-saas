CREATE OR REPLACE FUNCTION public.krim_vehicle_document_register(
 p_vehicle_id uuid,p_document_type text,p_document_number text,p_issuing_country_code text,
 p_issued_at date,p_expires_at date,p_storage_path text,p_original_file_name text,
 p_content_type text,p_file_size bigint
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();v_org bigint;v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 SELECT organization_id INTO v_org FROM public.krim_vehicles WHERE id=p_vehicle_id FOR UPDATE;
 IF v_org IS NULL THEN RAISE EXCEPTION USING errcode='P0002',message='Vehicle not found';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=v_org AND m.status='active' AND m.role IN('owner','manager')) THEN RAISE EXCEPTION USING errcode='42501',message='Active organisation owner or manager access is required';END IF;
 IF p_storage_path !~ ('^'||v_org::text||'/'||v_user::text||'/vehicle/'||p_vehicle_id::text||'/[A-Za-z0-9._-]+$') THEN RAISE EXCEPTION USING errcode='23514',message='Document storage path is invalid';END IF;
 IF NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='krim-partner-verification' AND o.name=p_storage_path AND o.owner_id=v_user::text) THEN RAISE EXCEPTION USING errcode='23503',message='Uploaded private storage object not found or not owned by uploader';END IF;
 IF p_content_type NOT IN('application/pdf','image/jpeg','image/png') OR p_file_size NOT BETWEEN 1 AND 10485760 THEN RAISE EXCEPTION USING errcode='23514',message='Unsupported file type or file size';END IF;
 IF p_expires_at IS NOT NULL AND p_issued_at IS NOT NULL AND p_expires_at<p_issued_at THEN RAISE EXCEPTION USING errcode='23514',message='Expiry date cannot precede issue date';END IF;
 INSERT INTO public.krim_vehicle_documents(vehicle_id,organization_id,document_type,document_number,issuing_country_code,issued_at,expires_at,storage_path,original_file_name,content_type,file_size,created_by)
 VALUES(p_vehicle_id,v_org,btrim(p_document_type),nullif(btrim(p_document_number),''),upper(btrim(p_issuing_country_code)),p_issued_at,p_expires_at,p_storage_path,btrim(p_original_file_name),p_content_type,p_file_size,v_user) RETURNING id INTO v_id;
 RETURN v_id;
END;$$;
REVOKE ALL ON FUNCTION public.krim_vehicle_document_register(uuid,text,text,text,date,date,text,text,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_vehicle_document_register(uuid,text,text,text,date,date,text,text,text,bigint) TO authenticated;
CREATE OR REPLACE FUNCTION public.krim_vehicle_documents_list(p_vehicle_id uuid)
RETURNS TABLE(id uuid,document_type text,document_number text,issuing_country_code text,issued_at date,expires_at date,original_file_name text,content_type text,file_size bigint,review_status text,review_reason text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();v_org bigint;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 SELECT organization_id INTO v_org FROM public.krim_vehicles WHERE id=p_vehicle_id;
 IF v_org IS NULL OR NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=v_org AND m.status='active') THEN RAISE EXCEPTION USING errcode='42501',message='Active organisation membership required';END IF;
 RETURN QUERY SELECT d.id,d.document_type,d.document_number,d.issuing_country_code,d.issued_at,d.expires_at,d.original_file_name,d.content_type,d.file_size,d.review_status,d.review_reason,d.created_at FROM public.krim_vehicle_documents d WHERE d.vehicle_id=p_vehicle_id ORDER BY d.created_at DESC;
END;$$;
REVOKE ALL ON FUNCTION public.krim_vehicle_documents_list(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_vehicle_documents_list(uuid) TO authenticated;