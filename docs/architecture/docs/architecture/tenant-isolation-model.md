# KRIM Logistics OS — Tenant Isolation Model

## 1. RLS Enforcement
Every table (`krim_shipments`, `krim_quotes`, `krim_organization_members`) implements strict Supabase Row Level Security (RLS). Queries automatically filter records based on `auth.uid()` and organization mapping, ensuring zero data leakage between competing enterprise shippers or carrier partners.
