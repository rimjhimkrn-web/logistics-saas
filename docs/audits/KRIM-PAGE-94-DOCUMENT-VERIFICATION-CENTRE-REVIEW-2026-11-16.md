# Page 94 — Document Verification Centre Review
Date: 2026-11-16

## Canonical route
- `public/documents/document-review.html`

## Findings and change
- The previous page showed a sample bill of lading, fixed 99.8% OCR accuracy, zero discrepancies, sanctions/customs validation success and pre-filled extracted fields as though they were real verification results.
- Removed the sample document, fabricated extraction values and unsupported compliance status.
- Replaced with an explicit not-connected state and documented evidence binding, field-level provenance, reviewer and separation-of-duties requirements.

## Safety / limits
- No document was uploaded, read, scanned, verified, approved or rejected.
- OCR extraction must not be represented as legal/regulatory clearance. Screening and human verification require their own authoritative evidence and audit trail.

## Commit
- `e3c778901369fe426d19958fd7dd520792fcee1a`
