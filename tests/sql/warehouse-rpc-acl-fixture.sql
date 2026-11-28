-- Synthetic PostgreSQL 16 ACL fixture. Function bodies are inert; behavior is reviewed separately against staging definitions.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS public;
CREATE OR REPLACE FUNCTION public.krim_warehouse_list_events(uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_task(bigint,uuid,text,text,text,text,text,numeric,text,text,text,text,text,text,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_dashboard() RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_review_inventory_quality(uuid,uuid,text,text) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_pick_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_list_tasks(text) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_transition_task(uuid,text,uuid,text) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_list_assigned_shipment_legs(bigint,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_goods_receipt_task(bigint,uuid,bigint,bigint,text,text,text,text,numeric,text,text,text,text,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_inbound_task(bigint,uuid,bigint,bigint,text,text,text,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_create_linked_handover_task(bigint,uuid,bigint,bigint,text,text,uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_register_facility(bigint,text,text,text,text,text,text) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_list_evidence(uuid) RETURNS integer LANGUAGE sql AS 'SELECT 1';
CREATE OR REPLACE FUNCTION public.krim_warehouse_register_evidence(uuid,text,text,text,timestamptz) RETURNS integer LANGUAGE sql AS 'SELECT 1';
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC, anon, authenticated, service_role;

-- Warehouse browser table-read fixture: RLS enabled, initially over-permissive grants.
CREATE TABLE public.krim_warehouse_facilities (id uuid, organization_id uuid);
CREATE TABLE public.krim_warehouse_inventory (id uuid, organization_id uuid, facility_id uuid);
CREATE TABLE public.krim_warehouse_tasks (id uuid, organization_id uuid, facility_id uuid);
CREATE TABLE public.krim_warehouse_shipment_allocations (id uuid, organization_id uuid, shipment_id uuid);
ALTER TABLE public.krim_warehouse_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.krim_warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.krim_warehouse_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.krim_warehouse_shipment_allocations ENABLE ROW LEVEL SECURITY;
CREATE POLICY warehouse_facility_tenant_read ON public.krim_warehouse_facilities FOR SELECT TO authenticated USING (organization_id = current_setting('krim.test_org_id',true)::uuid);
CREATE POLICY warehouse_inventory_tenant_read ON public.krim_warehouse_inventory FOR SELECT TO authenticated USING (organization_id = current_setting('krim.test_org_id',true)::uuid);
CREATE POLICY warehouse_tasks_tenant_read ON public.krim_warehouse_tasks FOR SELECT TO authenticated USING (organization_id = current_setting('krim.test_org_id',true)::uuid);
CREATE POLICY warehouse_allocations_tenant_read ON public.krim_warehouse_shipment_allocations FOR SELECT TO authenticated USING (organization_id = current_setting('krim.test_org_id',true)::uuid);
INSERT INTO public.krim_warehouse_facilities VALUES
 ('00000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
 ('00000000-0000-0000-0000-000000000002','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
INSERT INTO public.krim_warehouse_inventory VALUES
 ('00000000-0000-0000-0000-000000000011','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000012','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','00000000-0000-0000-0000-000000000002');
INSERT INTO public.krim_warehouse_tasks VALUES
 ('00000000-0000-0000-0000-000000000021','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000022','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','00000000-0000-0000-0000-000000000002');
INSERT INTO public.krim_warehouse_shipment_allocations VALUES
 ('00000000-0000-0000-0000-000000000031','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','cccccccc-cccc-cccc-cccc-cccccccccccc'),
 ('00000000-0000-0000-0000-000000000032','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','dddddddd-dddd-dddd-dddd-dddddddddddd');
GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.krim_warehouse_facilities, public.krim_warehouse_inventory,
 public.krim_warehouse_tasks, public.krim_warehouse_shipment_allocations
 TO PUBLIC, anon, authenticated, service_role;
