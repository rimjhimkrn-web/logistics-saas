# KRIM Page 54 — Pickup & Delivery Updates Review
Date: 2026-11-16

## Scope and canonical route
Page 54 is Pickup & Delivery Updates. The canonical authenticated workflow is `public/pickup-tracking.html`. Legacy routes `public/partner/pickup-confirmation.html` and `public/shipments/pickup.html` redirect here; the partner confirmation route explicitly retires its former demo success flow. The driver module `app/driver/module-05-pickup-collection.html` is a read-only assignment summary, not the milestone update form.

## Corrections made
Commit: `07163dfe39b0e95c198be13622d9b777c59210ed`

1. Removed the routine `delivered` option from the partner milestone selector. A generic milestone should not be used to declare final delivery; the separate proof-of-delivery verification process is the appropriate control.
2. Added explicit guidance that delivery completion must be established through the separate proof-of-delivery verification workflow.
3. Renamed the ETA field to **Recorded delivery estimate** and clarified that it is a stored estimate, not live ETA or carrier prediction.

## Workflow reviewed
- Requires an authenticated Supabase session.
- Loads shipment data through `krim_get_shipment_tracking`; access is determined by the server function.
- Partner milestone form is shown only when the response indicates `can_record`.
- Event submission calls `krim_record_operational_milestone`; this is a real operational write and was not invoked.
- Coordinates are optional and collected only after an explicit device-location action; no continuous GPS tracking is claimed.
- Timeline uses recorded tracking events and milestone records; unsupported external feeds are not implied.
- Legacy pickup confirmation pages redirect to the canonical workflow rather than showing a fabricated success.

## Backend controls not changed
Earlier backend review found that milestone recording and shipment-leg controls still require hardening: out-of-order milestone creation is possible, and `can_record` authorization appears broader than fine-grained operational permissions. These are production function issues and remain blocked pending migration reconciliation. Removing the routine delivered option from the UI is a safeguard, not a substitute for server-side enforcement.

## Testing boundary
No pickup, custody transfer, milestone, GPS event or delivery record was created. No production RPC was invoked. Automated repository checks are pending for this commit; authenticated partner/customer end-to-end tests remain outstanding.

## Page 54 status
**Unsafe routine delivery declaration removed from the form; ETA wording corrected; canonical pickup workflow identified. Automated checks pending.** Not production certification.
