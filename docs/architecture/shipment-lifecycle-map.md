# KRIM Logistics OS — Shipment Lifecycle Map

## 1. Consignment Progression States
A consignment moves through deterministic states stored in the immutable database vault:
1. `pending`: Initial booking request created via `/public/shipper/booking-request.html`.
2. `quoted_and_pending_bid`: Tariff calculation committed and broadcast to carrier spot markets.
3. `carrier_assigned`: Winning carrier spot bid accepted and escrow authorized.
4. `in_transit`: GPS telemetry broadcast active from carrier vehicles.
5. `hub_arrived`: Intermediate cross-docking intake scanned at warehouse terminals.
6. `customs_cleared`: Regulatory stamp issued by compliance officers.
7. `delivered`: Electronic Proof of Delivery (ePOD) digital signature verified and vaulted.
8. 
