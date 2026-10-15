# KRIM Logistics OS — Architecture Decision Records (ADRs)

## ADR-001: Supabase for Backend & Multi-Tenancy
* **Status**: Accepted
* **Context**: Requirement for secure database isolation, JWT auth, and real-time WebSocket telemetry without heavy backend server maintenance.
* **Decision**: Utilize Supabase PostgreSQL with built-in Row Level Security (RLS) and Edge Functions.

## ADR-002: Vanilla ES6 & Tailwind CDN for Frontend
* **Status**: Accepted
* **Context**: Need for instantaneous load times, zero complex build step dependencies, and reliable cross-device compatibility.
* **Decision**: Adopt pure HTML5 modules with Tailwind CSS via CDN and Supabase JS SDK.
* 
