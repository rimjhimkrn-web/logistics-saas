# KRIM Logistics OS — Deprecation and Migration Policy

## 1. Purpose
Protect live customer, shipment, financial, identity and partner workflows while the global platform evolves. No table, endpoint, page, event, or integration is removed merely because a replacement has been created.

## 2. Change Classification
- **Additive:** backward-compatible field/table/endpoint/event addition.
- **Behavioral:** changes validation, permissions, lifecycle, or response semantics.
- **Breaking:** removes/renames a field, endpoint, state, page, or integration contract.
- **Security/urgent:** required to contain an active vulnerability or unauthorized access.
- **Data migration:** transforms or reassigns existing persisted data.

Record significant decisions in [architecture decision records](architecture-decision-records.md) and update the relevant lifecycle, data-flow, dependency and API contracts.

## 3. Standard Expand–Migrate–Contract Process
1. Inventory consumers, database dependencies, RPCs, Edge Functions, scheduled jobs, webhooks, frontend pages, external partners and reports.
2. Add the replacement in a backward-compatible form.
3. Deploy server-side compatibility and observability.
4. Backfill/migrate data using repeatable, bounded and validated steps.
5. Verify row counts, constraints, financial totals, tenant ownership and representative workflows.
6. Move consumers gradually; monitor errors and usage.
7. Deprecate old behavior with a documented date/window and migration instructions.
8. Remove old behavior only after usage is zero or an approved exception exists, backups/rollback are verified, and owner approval is recorded.

## 4. Database and Financial Safety
- Use versioned migrations and preserve a clear deployment order.
- Prefer additive schema changes before destructive cleanup.
- Do not run unbounded production updates without a reviewed plan.
- Never silently rewrite ledger history or delete financial evidence. Use reversal/adjustment entries with audit trails.
- Make data migrations idempotent where practical and provide preflight/postflight checks.
- Validate tenant ownership and foreign-key integrity before and after migration.
- Do not store secrets or personal data in migration names, logs or documentation.

## 5. API and Frontend Compatibility
- Document endpoint version/compatibility expectations and response/error schemas.
- Avoid breaking changes without a migration window unless security or legal risk requires immediate action.
- Update the frontend contract, tests, docs, monitoring and release notes together.
- Keep route redirects only when they do not weaken authentication or leak private data.
- Do not claim a UI migration complete until links, mobile behavior, authorization and backend actions are verified.

## 6. Rollback and Recovery
Each material migration must define:
- Preconditions and backup/recovery approach.
- Expected row counts/invariants and validation queries.
- Failure detection and stop conditions.
- Roll-forward or rollback steps, including whether rollback is safe after writes begin.
- Owner, execution window, and evidence of completion.

For irreversible changes, use a staged roll-forward recovery plan rather than promising rollback.

## 7. Required Checklist
- [ ] Consumer/dependency inventory complete.
- [ ] Migration reviewed and tested in a non-production environment where available.
- [ ] Preflight checks and recovery plan documented.
- [ ] Data integrity, tenant isolation and financial invariants verified.
- [ ] Monitoring and alerting prepared.
- [ ] Documentation and dependent consumers updated.
- [ ] Post-deployment validation evidence attached.
- [ ] Old path removed only after an approved deprecation gate.

**Rule:** A migration file existing in GitHub is not proof that it has been applied to Supabase or safely completed.
