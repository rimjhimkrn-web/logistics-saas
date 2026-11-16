# KRIM Page 63 — Customs Documentation
Date: 2026-11-16

## Canonical page
`app/customer/customs-documents.html` — Customer shipment customs documents.

## Access and workflow
- Authenticated customer session and active customer-organization membership required.
- Customer shipment list is capped at 500; visible customs records, document submissions and broker assignments are each capped at 500.
- Upload requires `shipment.update` for the shipment's customer organization.
- Upload accepts PDF, JPEG or PNG up to 10 MB and records private evidence through `krim_customs_document_submit`.
- Private evidence previews use 60-second signed URLs.
- Customer-side rejection is separately guarded by AAL2 and server-side review RPC. Customer page does not approve customs evidence or file a declaration.

## Changes
Commit: `af811575217541c672d951eeaceda6394473a7aa`
- Added safe date rendering for submitted evidence.
- Validates shipment, customs-record, document and broker-assignment query result shapes before rendering.
- Unexpected response payloads now fail closed rather than being treated as empty records.

## Limitations
- Query limits and RLS visibility mean the page is not a complete cross-platform customs register.
- Uploaded documents remain pending review until the authorized review workflow verifies them.
- No customs authority filing, duty payment, inspection outcome or release is established by document upload.

## Verification
No evidence was uploaded, rejected, approved, opened or deleted. No customs record or shipment was changed. Database and storage controls were reviewed from repository source; no production mutation was performed.
