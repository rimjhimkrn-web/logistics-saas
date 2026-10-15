# KRIM Logistics OS — System Dependency Map

## 1. Core Infrastructure Dependencies
* **Database Engine**: PostgreSQL 15+ hosted on Supabase managed infrastructure with point-in-time recovery and automated backups.
* **Authentication Provider**: Supabase GoTrue Auth service supporting JWT tokens, email verification, and TOTP MFA (AAL2).
* **Payment Gateway**: Razorpay REST APIs and webhook edge functions for currency processing and escrow settlement.
* **Frontend CDN & Styling**: Tailwind CSS modern styling engine (via CDN build) and vanilla ES6 modular JavaScript.
* 
