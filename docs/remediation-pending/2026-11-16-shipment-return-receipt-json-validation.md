# Shipment return receipt JSON validation and atomicity remediation

Date: 2026-11-16  
Status: live defect confirmed; remediation specification only  
Scope: `krim_receive_authorized_shipment_return(uuid,uuid,jsonb,uuid,text)`

## Confirmed defect

The live function's first validation condition checks:

`jsonb_typeof(p_received_items) <> 'array' OR jsonb_array_length(p_received_items) < 1 OR jsonb_array_length(p_received_items) > 100`

It does not explicitly check `p_received_items IS NULL`.

In PostgreSQL, SQL NULL comparisons and boolean expressions can evaluate to NULL rather than TRUE. In a PL/pgSQL `IF`, a NULL condition is not taken as TRUE. Consequently, SQL NULL can bypass this initial validation. Subsequent array-length comparisons can also evaluate to NULL, and `jsonb_array_elements(NULL)` yields no item rows. The function can therefore proceed through receipt creation and the return status update without reconciling any manifest lines, subject to the remaining live constraints.

This is a P1/P0-class integrity defect for physical return receipt: the function may record a return as received/inspection_hold without item-level physical reconciliation.

## Additional validation gaps to harden

The current loop:
- checks `manifest_index` with a digit-only regular expression before integer cast;
- checks index bounds and duplicate indexes;
- casts quantity to numeric before a fully explicit JSON type/presence check;
- compares quantity, unit and description to the authorised manifest line;
- records received inventory with quality status `hold`, which is a positive safety control.

The remediation must explicitly reject SQL NULL, JSON null, non-array values, empty/oversized arrays, non-object elements, absent/null/wrong-type required properties, malformed numeric strings, non-finite values, duplicate/out-of-range indexes, and malformed/null authorised manifests before inserting a receipt or inventory movement.

## Required remediation

1. First validation must explicitly include `p_received_items IS NULL`, `jsonb_typeof(p_received_items) IS DISTINCT FROM 'array'`, and array length bounds. Do not rely on nullable comparisons.
2. Validate the authorised `item_manifest` itself as a non-null array with a permitted non-zero bounded length before comparing or iterating.
3. Require every array element to be a JSON object.
4. Require `manifest_index` and `quantity` to be present, non-JSON-null, and of explicitly accepted JSON types. Validate lexical numeric format and bounded precision/scale before casting.
5. Require SKU, unit and description to be present, non-null strings, trimmed, non-empty and within defined lengths. Validate optional lot-code type and bounds.
6. Check each manifest index exactly once and ensure the submitted set covers every authorised manifest line. Keep exact quantity/unit/description comparisons and define case/normalization rules consistently.
7. Validate all input lines completely before creating receipt or inventory rows. Although transaction rollback protects atomicity on exception, prevalidation produces clearer errors and avoids coupling validation to side effects.
8. Preserve the positive control: return inventory enters quality status `hold`; it must not become released stock until the independent inspection and second-review workflow succeeds.
9. Preserve idempotency by comparing canonical payload content on replay, not only return ID, facility, user and idempotency key. Same key with changed item content must reject.
10. Ensure a receipt with zero receipt items is impossible at the database level as well as in the RPC. Inspect existing constraints/triggers and historical data before proposing a constraint.
11. Audit every alternate receipt writer and privileged/service-role path. A corrected RPC alone is insufficient if direct writes or another SECURITY DEFINER function can mark a return received.
12. Review function ownership, fixed search_path, execute ACLs, RLS and tenant isolation. Do not broaden grants.

## Staging verification matrix

Use isolated staging and synthetic records only; do not invoke this business function against production data.

- SQL NULL `p_received_items` rejects before any writes.
- JSON literal `null`, object, string, number and boolean reject.
- Empty array and arrays over the configured maximum reject.
- Null/non-object array elements reject.
- Missing, JSON-null, wrong-type and malformed fields reject.
- NaN/infinity, zero, negative, excessive precision and overflow quantities reject.
- Duplicate, negative, non-numeric and out-of-range manifest indexes reject.
- Missing manifest line rejects; every valid line is reconciled exactly once.
- A valid receipt creates one receipt, exactly N receipt items and N inventory receipt movements, all on hold.
- Any injected failure rolls back receipt, items, inventory movements, return status and audit event.
- Identical retry replays without duplicate inventory; conflicting payload retry rejects.
- Wrong tenant, facility, operator, return status and unapproved facility reject.
- Independent QC and second-review controls remain mandatory before stock release.
- Verify no zero-item receipt can be committed through any alternate writer.

## Release decision

**NO-GO for physical return receipt until explicit null/type validation, canonical idempotency, zero-item prevention and atomic staging tests pass.**

This document is not a migration and has not been applied. Production DDL remains blocked by the unresolved migration-history reconciliation.
