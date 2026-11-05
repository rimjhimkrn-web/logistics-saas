CREATE TABLE IF NOT EXISTS public.krim_vehicles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id bigint NOT NULL REFERENCES public.krim_organizations(id) ON DELETE RESTRICT,
 legacy_fleet_id bigint UNIQUE REFERENCES public.partner_fleet(id) ON DELETE SET NULL,
 registration_country_code text NOT NULL,
 registration_region text,
 registration_number text NOT NULL,
 vehicle_category text NOT NULL,
 vehicle_type text NOT NULL,
 make text,model text,manufacture_year integer,
 payload_capacity numeric(14,3),payload_unit text,
 ownership_type text NOT NULL DEFAULT 'partner_owned',
 operational_status text NOT NULL DEFAULT 'pending_verification',
 verification_status text NOT NULL DEFAULT 'pending',
 verified_at timestamptz,verified_by uuid REFERENCES auth.users(id),
 created_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT krim_vehicles_country_code_ck CHECK(registration_country_code ~ '^[A-Z]{2}$'),
 CONSTRAINT krim_vehicles_reg_number_ck CHECK(length(btrim(registration_number)) BETWEEN 2 AND 40),
 CONSTRAINT krim_vehicles_category_ck CHECK(length(btrim(vehicle_category)) BETWEEN 2 AND 60),
 CONSTRAINT krim_vehicles_type_ck CHECK(length(btrim(vehicle_type)) BETWEEN 2 AND 80),
 CONSTRAINT krim_vehicles_year_ck CHECK(manufacture_year IS NULL OR manufacture_year BETWEEN 1900 AND 2200),
 CONSTRAINT krim_vehicles_capacity_ck CHECK(payload_capacity IS NULL OR payload_capacity>0),
 CONSTRAINT krim_vehicles_ownership_ck CHECK(ownership_type IN('partner_owned','leased','contracted','customer_owned','other')),
 CONSTRAINT krim_vehicles_status_ck CHECK(operational_status IN('pending_verification','active','maintenance','suspended','retired')),
 CONSTRAINT krim_vehicles_verification_ck CHECK(verification_status IN('pending','in_review','verified','rejected','expired'))
);
CREATE UNIQUE INDEX IF NOT EXISTS krim_vehicles_org_registration_uidx ON public.krim_vehicles(organization_id,registration_country_code,upper(registration_number));
CREATE INDEX IF NOT EXISTS krim_vehicles_org_status_idx ON public.krim_vehicles(organization_id,operational_status,verification_status);
CREATE TABLE IF NOT EXISTS public.krim_vehicle_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 vehicle_id uuid NOT NULL REFERENCES public.krim_vehicles(id) ON DELETE RESTRICT,
 organization_id bigint NOT NULL REFERENCES public.krim_organizations(id) ON DELETE RESTRICT,
 document_type text NOT NULL,document_number text,issuing_country_code text NOT NULL,
 issued_at date,expires_at date,storage_path text NOT NULL,original_file_name text NOT NULL,
 content_type text NOT NULL,file_size bigint NOT NULL,
 review_status text NOT NULL DEFAULT 'pending',review_reason text,
 reviewed_by uuid REFERENCES auth.users(id),reviewed_at timestamptz,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT krim_vehicle_docs_type_ck CHECK(length(btrim(document_type)) BETWEEN 2 AND 80),
 CONSTRAINT krim_vehicle_docs_country_ck CHECK(issuing_country_code ~ '^[A-Z]{2}$'),
 CONSTRAINT krim_vehicle_docs_size_ck CHECK(file_size BETWEEN 1 AND 15728640),
 CONSTRAINT krim_vehicle_docs_review_ck CHECK(review_status IN('pending','in_review','approved','rejected','expired'))
);
CREATE INDEX IF NOT EXISTS krim_vehicle_docs_vehicle_idx ON public.krim_vehicle_documents(vehicle_id,review_status,expires_at);
ALTER TABLE public.krim_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.krim_vehicle_documents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.krim_vehicles,public.krim_vehicle_documents FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.krim_vehicle_register(p_organization_id bigint,p_registration_country_code text,p_registration_region text,p_registration_number text,p_vehicle_category text,p_vehicle_type text,p_make text DEFAULT NULL,p_model text DEFAULT NULL,p_manufacture_year integer DEFAULT NULL,p_payload_capacity numeric DEFAULT NULL,p_payload_unit text DEFAULT NULL,p_ownership_type text DEFAULT 'partner_owned',p_legacy_fleet_id bigint DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=p_organization_id AND m.status='active' AND m.role IN('owner','manager')) THEN RAISE EXCEPTION USING errcode='42501',message='Active organisation owner or manager access is required';END IF;
 IF p_legacy_fleet_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.partner_fleet f WHERE f.id=p_legacy_fleet_id AND f.krim_organization_id=p_organization_id) THEN RAISE EXCEPTION USING errcode='23514',message='Legacy fleet record does not belong to this organisation';END IF;
 INSERT INTO public.krim_vehicles(organization_id,legacy_fleet_id,registration_country_code,registration_region,registration_number,vehicle_category,vehicle_type,make,model,manufacture_year,payload_capacity,payload_unit,ownership_type,created_by)
 VALUES(p_organization_id,p_legacy_fleet_id,upper(btrim(p_registration_country_code)),nullif(btrim(p_registration_region),''),btrim(p_registration_number),btrim(p_vehicle_category),btrim(p_vehicle_type),nullif(btrim(p_make),''),nullif(btrim(p_model),''),p_manufacture_year,p_payload_capacity,nullif(btrim(p_payload_unit),''),p_ownership_type,v_user) RETURNING id INTO v_id;
 RETURN v_id;
END;$$;
REVOKE ALL ON FUNCTION public.krim_vehicle_register(bigint,text,text,text,text,text,text,text,integer,numeric,text,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_vehicle_register(bigint,text,text,text,text,text,text,text,integer,numeric,text,text,bigint) TO authenticated;
CREATE OR REPLACE FUNCTION public.krim_vehicle_list(p_organization_id bigint)
RETURNS TABLE(id uuid,registration_country_code text,registration_region text,registration_number text,vehicle_category text,vehicle_type text,make text,model text,manufacture_year integer,payload_capacity numeric,payload_unit text,ownership_type text,operational_status text,verification_status text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION USING errcode='28000',message='Authentication required';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.krim_organization_members m WHERE m.user_id=v_user AND m.organization_id=p_organization_id AND m.status='active') THEN RAISE EXCEPTION USING errcode='42501',message='Active organisation membership is required';END IF;
 RETURN QUERY SELECT v.id,v.registration_country_code,v.registration_region,v.registration_number,v.vehicle_category,v.vehicle_type,v.make,v.model,v.manufacture_year,v.payload_capacity,v.payload_unit,v.ownership_type,v.operational_status,v.verification_status,v.created_at FROM public.krim_vehicles v WHERE v.organization_id=p_organization_id ORDER BY v.created_at DESC;
END;$$;
REVOKE ALL ON FUNCTION public.krim_vehicle_list(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.krim_vehicle_list(bigint) TO authenticated;