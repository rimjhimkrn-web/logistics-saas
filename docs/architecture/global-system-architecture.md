# KRIM Logistics OS — Global System Architecture

## 1. Architectural Principles
* **Zero-Trust Multi-Tenancy**: Data isolation strictly enforced via PostgreSQL Row Level Security (RLS) policies keyed to organization memberships.
* **Stateless Edge Compute**: Authentication and payment validation executed via secure serverless edge functions.
* **Immutability of Financial Ledgers**: All transactions, bids, and settlements record immutable audit trails.

## 2. Technical Stack
* **Frontend**: HTML5, Tailwind CSS (Modern Styling Engine), vanilla JavaScript ES6+ modules with Supabase JS SDK v2.
* **Backend**: Supabase PostgreSQL, Edge Functions, Auth (JWT + TOTP MFA).
* 
