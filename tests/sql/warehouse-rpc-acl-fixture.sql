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
