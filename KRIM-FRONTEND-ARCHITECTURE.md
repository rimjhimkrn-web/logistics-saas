# KRIM FRONTEND ARCHITECTURE

## 1. Purpose

This document defines the permanent frontend architecture for KRIM Logistics.

KRIM is designed as a global logistics operating system.

The frontend must therefore remain:

- global by architecture
- modular
- secure
- responsive
- reusable
- maintainable
- scalable
- consistent across markets
- consistent across customer, partner and operations interfaces

India is the first active market, not the architectural boundary.

---

# 2. Core Architecture Principle

KRIM follows:

BUILD GLOBAL BY ARCHITECTURE.
ACTIVATE MARKETS BY NETWORK.

The frontend must not be rebuilt when KRIM enters another country or market.

Market-specific behavior must be controlled through configuration, backend data, permissions and business rules.

---

# 3. Frontend Layers

KRIM frontend is divided into these layers:

1. Design System
2. Platform Services
3. Platform Shell
4. Authentication
5. Workspaces
6. Operating Domains
7. Public and Trust Pages

---

# 4. Design System

Core files:

- krim-core.css
- krim-components.css
- krim-responsive.css

Responsibilities:

krim-core.css
- colors
- typography
- spacing
- surfaces
- base layout
- common states

krim-components.css
- cards
- buttons
- forms
- tables
- badges
- reusable interface components

krim-responsive.css
- mobile
- tablet
- laptop
- desktop
- large-screen behavior

RULE:

Common visual behavior must be created here instead of being duplicated inside individual pages.

---

# 5. Platform Services

Core files:

- krim-config.js
- krim-auth.js
- krim-api.js
- krim-ui.js
- krim-security.js

Responsibilities:

krim-config.js
- platform configuration
- Supabase configuration
- route configuration
- market defaults

krim-auth.js
- authentication session
- current user
- authentication state
- logout
- protected route foundation

krim-api.js
- common API requests
- authenticated requests
- GET
- POST
- PATCH
- DELETE

krim-ui.js
- loading states
- errors
- text handling
- number formatting
- currency formatting
- common UI behavior

krim-security.js
- frontend security safeguards
- role-aware UI checks
- safe URL handling
- input sanitization helpers

IMPORTANT:

Frontend security is NOT the final authorization boundary.

Real authorization remains enforced by:

- Supabase Auth
- RBAC
- PostgreSQL RLS
- security-definer functions
- Edge Functions
- backend authorization rules

---

# 6. Platform Shell

Primary shell:

- krim-platform-shell.html

The shell defines the common KRIM platform structure.

The shell must provide a consistent experience for:

- navigation
- branding
- platform context
- market context
- workspace context
- responsive behavior

The shell must not expose privileged operations to public users.

---

# 7. Global Workspace

Primary workspace:

- krim-global-workspace.html

The global workspace represents the overall KRIM operating platform.

It provides visibility into major operating domains.

It is not a replacement for role-specific authorization.

---

# 8. Authentication

Authentication files:

- login.html
- mfa.html
- forgot-password.html
- reset-password.html

Authentication flow:

User
↓
Login
↓
Supabase Authentication
↓
Session
↓
MFA when required
↓
User identity
↓
Organization
↓
Role
↓
Permission
↓
Workspace
↓
RLS/backend authorization

Authentication must never be implemented only through frontend JavaScript.

---

# 9. Workspaces

Primary workspaces:

- customer-workspace.html
- partner-workspace.html
- operations-workspace.html

Customer:

- shipments
- quotes
- tracking
- documents
- finance
- support

Partner:

- assigned work
- capacity
- dispatch
- tracking
- documents
- POD
- partner finance

Operations:

- control tower
- network
- shipments
- capacity
- exceptions
- claims
- compliance
- finance
- analytics
- integrations
- AI
- system health

---

# 10. Role Boundaries

PUBLIC

Cannot access privileged operations.

CUSTOMER

Cannot access partner or operations workspace.

PARTNER

Cannot access customer or operations workspace.

OPERATIONS

Privileged access.

Operations access requires appropriate:

- authentication
- MFA
- RBAC
- RLS
- audit controls

Frontend navigation must never be treated as the security boundary.

---

# 11. Operating Domains

Initial domain pages:

- shipments.html
- tracking.html
- quotes.html
- network.html
- partners.html
- capacity.html
- finance.html
- documents.html
- compliance.html
- exceptions.html
- claims.html
- analytics.html
- integrations.html
- ai.html

These pages represent business domains.

They must reuse the shared KRIM platform foundation.

---

# 12. Domain Page Rule

A domain page should contain domain-specific behavior only.

For example:

shipments.html

may contain:

- shipment list
- shipment details
- status
- route
- assignment
- dispatch
- tracking

But it should NOT duplicate:

- global colors
- authentication implementation
- API framework
- currency formatter
- responsive framework
- security framework

Those belong to shared layers.

---

# 13. Public and Trust Pages

Public files:

- home.html
- terms.html
- privacy.html
- refund.html
- acceptable-use.html
- cookies.html

These pages must not expose:

- operations controls
- customer data
- partner data
- internal analytics
- privileged administration

Legal and policy content must reflect KRIM's actual commercial and operational behavior.

---

# 14. Global Design Rule

All KRIM interfaces must use the same visual language.

Required consistency:

- KRIM logo
- KRIM colors
- typography
- buttons
- cards
- forms
- tables
- badges
- status indicators
- spacing
- responsive behavior
- navigation language

Different workspaces may have different information density, but they must still look like one KRIM platform.

---

# 15. Global Market Architecture

KRIM must support:

- country
- market
- currency
- timezone
- language
- regional operating rules
- compliance requirements

Market-specific values must not be hard-coded into every page.

Example:

BAD:

    if India then use INR

    GOOD:

        read active market configuration

        The backend remains the authoritative source for operational market configuration.

        ---

        # 16. API Rule

        Frontend pages should communicate with the backend through the shared API layer whenever practical.

        Primary interface:

            krim-api.js

            Do not create a different API implementation for every page.

            Authentication tokens must be handled through the established authentication/session mechanism.

            ---

            # 17. Security Rule

            Never rely on:

            - hidden buttons
            - hidden links
            - frontend role checks
            - URL obscurity
            - HTML restrictions

            for real authorization.

            Real authorization must be enforced server-side.

            Security layers include:

            - Supabase Auth
            - MFA
            - RBAC
            - RLS
            - backend functions
            - Edge Functions
            - audit events
            - idempotency
            - webhook validation
            - security monitoring

            ---

            # 18. Data Rule

            Frontend pages must not directly assume that frontend values are authoritative.

            Important operational values such as:

            - permissions
            - shipment ownership
            - organization access
            - financial state
            - compliance state
            - workflow state
            - partner access

            must be validated by the backend.

            ---

            # 19. Responsive Rule

            KRIM must work across:

            - Android phones
            - iPhones
            - tablets
            - laptops
            - desktops
            - large monitors

            Mobile is not a secondary design.

            Important workflows must remain usable on small screens.

            ---

            # 20. New Feature Rule

            When adding a new KRIM feature, first determine:

            1. Is it a shared component?
            2. Is it a platform service?
            3. Is it a workspace feature?
            4. Is it an operating domain?
            5. Is it market-specific?
            6. Is it backend-only?

            Do not create a new file automatically.

            Reuse existing architecture whenever possible.

            ---

            # 21. Extension Rule

            The initial frontend architecture is a permanent CORE, not a permanent maximum file count.

            Future KRIM capabilities may add domain modules.

            Examples:

            - ocean.html
            - air.html
            - warehouse.html
            - customs.html
            - fleet.html
            - container.html
            - port.html
            - control-tower.html

            Such additions must reuse the existing KRIM foundation.

            The foundation should not be rebuilt for each new feature.

            ---

            # 22. Locked File Rule

            Once a core file is tested and confirmed working, it should not be casually replaced.

            Changes should be:

            - intentional
            - documented
            - tested
            - backward-compatible where possible

            Existing working files must not be replaced merely to introduce a new feature.

            ---

            # 23. Development Rule

            KRIM development follows:

            ONE TASK
            ↓
            IMPLEMENT
            ↓
            TEST
            ↓
            CONFIRM
            ↓
            COMMIT
            ↓
            NEXT TASK

            Do not make large groups of untested changes.

            ---

            # 24. Repository Philosophy

            The repository should remain understandable to a future developer.

            File names must be:

            - descriptive
            - consistent
            - lowercase where appropriate
            - domain-oriented
            - predictable

            Avoid unnecessary duplicate versions such as:

            - page-new.html
            - page-final.html
            - page-final2.html
            - page-working.html

            If a new architecture is required, document the transition clearly.

            ---

            # 25. Permanent KRIM Architecture

            The intended long-term structure is:

            KRIM PLATFORM
            │
            ├── DESIGN SYSTEM
            │
            ├── PLATFORM SERVICES
            │
            ├── PLATFORM SHELL
            │
            ├── AUTHENTICATION
            │
            ├── CUSTOMER WORKSPACE
            │
            ├── PARTNER WORKSPACE
            │
            ├── OPERATIONS WORKSPACE
            │
            ├── OPERATING DOMAINS
            │
            ├── PUBLIC / TRUST
            │
            └── GLOBAL BACKEND OPERATING ENGINE

            All layers work together as one platform.

            ---

            # 26. Final Principle

            KRIM is not a collection of HTML pages.

            KRIM is one global logistics platform with:

            - one identity
            - one design system
            - one authentication architecture
            - one security model
            - one API architecture
            - one operating engine
            - multiple authorized workspaces
            - multiple operating domains
            - multiple global markets

            Build the foundation once.

            Extend the platform without rebuilding the foundation.