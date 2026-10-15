# KRIM Logistics OS — Application Boundaries

## 1. Boundary Separation
The application is segmented into explicit routing directories:
* `/auth/`: Public authentication, registration, and AAL2 MFA enrollment portals.
* `/app/`: Authenticated role-based workspaces (`/customer/`, `/partner/`, `/warehouse/`, `/compliance/`, `/admin/`).
* `/public/`: Public tracking, quotation verification, ePOD vaults, and marketplace boards.
* 
