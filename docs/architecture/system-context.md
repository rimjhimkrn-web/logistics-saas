# KRIM Logistics OS — System Context

## 1. Executive Overview
KRIM Logistics OS is an institutional-grade, multi-tenant Global Logistics Operating System engineered to orchestrate international freight, supply chain telemetry, carrier bidding, regulatory compliance, and escrow financial settlements.

## 2. System Boundaries & Actors
The KRIM OS ecosystem operates across five distinct institutional personas:
1. **Enterprise Shippers**: Corporate entities booking, tracking, and paying for freight consignments.
2. **Carrier Partners**: Fleet operators, trucking enterprises, and air/ocean carriers bidding on loads and reporting GPS telemetry.
3. **Hub & Warehouse Operators**: Terminal supervisors managing cross-docking intake and waybill scanning.
4. **Customs & Compliance Officers**: Regulatory officials auditing cross-border trade documents and stamping clearance.
5. **Platform Super Admins**: System-wide governors managing multi-tenant security, fee configurations, and global overrides.

## 3. External Integrations
* **Database & Auth Engine**: Supabase (PostgreSQL with Row Level Security and AAL2/TOTP MFA).
* **Payment Gateway**: Razorpay Edge Functions for cryptographically verified payment processing and escrow settlement.
* 
