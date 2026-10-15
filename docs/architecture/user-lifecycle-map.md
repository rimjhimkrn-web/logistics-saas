# KRIM Logistics OS — User Lifecycle Map

## 1. Executive Summary
The user lifecycle in KRIM OS governs how institutional actors enter the system, establish cryptographic identity, undergo multi-factor authentication, and transition through role-based workspaces.

## 2. Lifecycle Stages
1. **Acquisition & Registration**: Self-service or enterprise-provisioned signup via `/auth/signup.html` or `/auth/partner-signup.html`. Captures organizational metadata and transport mode.
2. **AAL2 Identity Provisioning**: Mandatory generation of TOTP secrets and enrollment of second-factor authenticators.
3. **Workspace Routing**: Dynamic redirection to role-specific command centers (`/app/customer/`, `/app/partner/`, `/app/warehouse/`, `/app/compliance/`, `/app/admin/`).
4. **Active Governance & Termination**: Continuous session monitoring via Supabase JWT with automated secure sign-out and tenant revocation.
5. 
