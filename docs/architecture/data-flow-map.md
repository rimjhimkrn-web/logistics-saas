# KRIM Logistics OS — Data Flow Map

## 1. Overview
This document outlines the secure transit of data across client browsers, edge compute functions, and the Supabase PostgreSQL data cluster.

## 2. Core Data Pipelines
1. **Client Request Initiation**: Browser applications submit payloads via HTTPS using the Supabase JavaScript SDK.
2. **Edge Validation & Auth**: Requests pass through Supabase API gateways where JWT and RLS policies evaluate tenant permissions.
3. **Database Ledger Commit**: Validated payloads are committed to PostgreSQL tables (`krim_shipments`, `krim_quotes`) with automated timestamp auditing.
4. **Real-time Telemetry Broadcast**: GPS pings and status updates propagate instantly to connected dashboards using Supabase Realtime channels.
5. 
