# KRIM Institutional Interface Standard

## Purpose

KRIM Logistics is architected as a global logistics operating system.

The interface must therefore present KRIM as one coherent institutional platform across public, authenticated, operational, partner, customer, security, legal and intelligence surfaces.

India is the first activated market, not the architectural boundary.

---

## 1. Core Principle

KRIM must feel like one global institution.

Every interface must share:

- KRIM identity
- KRIM design language
- KRIM navigation principles
- KRIM security model
- KRIM global-market model
- KRIM information hierarchy
- KRIM accessibility standards
- KRIM responsive behavior

Pages must never feel like unrelated mini-applications.

---

## 2. Global Platform Model

KRIM consists of four major interface layers.

### Public Layer

Includes:

- KRIM home
- Platform capabilities
- Global network
- Markets
- Industry coverage
- Trust
- Legal
- Privacy
- Terms
- Refund policy
- Acceptable use
- Cookies
- Public contact/access

Public interfaces explain KRIM without exposing protected operational information.

### Identity and Security Layer

Includes:

- Sign in
- Password recovery
- Password reset
- MFA
- Session management
- Authentication assurance
- Secure redirects
- Role-aware access
- Security messaging

Authentication must remain consistent with Supabase Auth, RBAC, RLS and backend authorization.

### Workspace Layer

Includes:

- Customer workspace
- Partner workspace
- Operations workspace

Each workspace exposes only the capabilities authorized for that user or organization.

### Operating Layer

Includes:

- Shipments
- Tracking
- Quotes
- Network
- Partners
- Capacity
- Finance
- Documents
- Compliance
- Exceptions
- Claims
- Analytics
- Integrations
- KRIM AI

---

## 3. Global-First Architecture

KRIM interfaces must support global operation from the beginning.

The interface architecture must accommodate:

- Country
- Market
- Region
- Currency
- Time zone
- Language
- Date format
- Number format
- Transport mode
- Regulatory environment
- Compliance requirements
- Local operating rules

India is the default initial market context.

The UI must not hard-code India-specific assumptions into the global architecture.

---

## 4. Institutional Visual Language

KRIM must communicate:

- reliability
- operational clarity
- security
- scale
- intelligence
- precision
- trust
- professionalism

The visual system must be:

- clean
- restrained
- information-rich
- accessible
- responsive
- consistent
- enterprise appropriate

Avoid:

- excessive decoration
- consumer-app visual clutter
- unnecessary gradients
- cartoon-like illustrations
- excessive animations
- inconsistent page layouts
- duplicate navigation systems
- isolated page-specific design languages

---

## 5. Information Hierarchy

Every authenticated page should clearly communicate:

1. Where the user is
2. Which workspace they are using
3. Which market/context is active
4. What requires attention
5. What the user can do
6. What operational information is available
7. What security/session state applies

Primary information must remain immediately understandable on mobile as well as desktop.

---

## 6. Global Workspace Structure

Authenticated KRIM workspaces should generally follow:

```text
KRIM Identity
        ↓
Global Context
        ↓
Workspace Context
        ↓
Primary Navigation
        ↓
Operational Overview
        ↓
Alerts / Exceptions
        ↓
Core Data
        ↓
Actions
        ↓
Analytics / Intelligence
