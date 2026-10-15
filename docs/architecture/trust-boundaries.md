# KRIM Logistics OS — Trust Boundaries

## 1. Boundary Definitions
* **Boundary A (Client Browser to API Gateway)**: Encrypted via TLS 1.3. Untrusted execution environment where user inputs are sanitized and JWT tokens are stored securely.
* **Boundary B (API Gateway to Database / RLS)**: Enforces strict tenant separation. Direct database access is blocked; all queries must satisfy PostgreSQL Row Level Security policies.
* **Boundary C (Third-Party Payment & Telemetry)**: Encrypted webhook exchanges with Razorpay and verified cryptographic signature headers.
* 
