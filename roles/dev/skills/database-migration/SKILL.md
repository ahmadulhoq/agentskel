---
name: database-migration
license: MIT
description: When writing, reviewing, or running a database schema migration — adding, dropping, or altering tables, columns, indexes, or constraints — with any migration tool (Alembic, Rails, Prisma, Room, Core Data, Flyway, Liquibase, raw SQL). Use before generating a migration file, or when one appears in a diff/PR.
---

# Database Migration Standards

## Step 1 — Identify the Migration System
- [ ] Find the existing migration directory/tool in use (grep for `migrations/`, `alembic/`, `db/migrate/`, Room `@Database` version, Core Data model versions, `prisma/migrations/`).
- [ ] Match the existing naming/ordering convention exactly (timestamp prefix, sequence number, etc).
- [ ] Never introduce a new migration tool or pattern when one is already established.

## Step 2 — Reversibility
- [ ] Every migration must have a working rollback path (`down`/`revert`) unless the platform doesn't support one — state why in the migration if so.
- [ ] Test the rollback, not just the forward migration.

## Step 3 — Backward Compatibility (Zero-Downtime)
- [ ] Assume old application code may still run against the new schema during a rolling deploy.
- [ ] Additive first: add new columns/tables nullable or with a default; ship code that uses them; only drop/rename the old ones in a *later* migration once old code is fully retired.
- [ ] Never rename or drop a column/table in the same migration that introduces its replacement — split across separate migrations/deploys.
- [ ] Treat a rename as two migrations: add new, backfill, then remove old.

## Step 4 — Data Safety
- [ ] Any destructive operation (`DROP COLUMN`, `DROP TABLE`, `TRUNCATE`, a data-losing type change) requires explicit user confirmation before applying — flag it in the plan, don't just run it.
- [ ] Batch large-table backfills; don't lock/rewrite the whole table in one transaction.
- [ ] Add `NOT NULL` only after backfilling existing rows — never add it without a default on a populated table.

## Step 5 — Performance & Locking
- [ ] Check whether the target table is large or hot; avoid migrations that take table-level locks on production-sized tables without a concurrency-safe strategy (e.g. `CREATE INDEX CONCURRENTLY` in Postgres, online DDL tools for MySQL).
- [ ] Index creation/removal on hot paths must use the platform's concurrent/online option.

## Step 6 — Never Edit an Applied Migration
- [ ] Once a migration has been merged or deployed, never edit it — write a new migration for further changes. Editing history breaks checksums and desyncs teammates' local state.

## Step 7 — Verify
- [ ] Run the migration up and down against a local/test database before committing.
- [ ] Confirm dependent application code is compatible with both pre- and post-migration schema state during rollout.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "It's a small table, I'll add NOT NULL directly" | Even small tables can have rows that violate the constraint. | Backfill existing rows, then add the constraint. |
| "I'll just rename the column, it's simpler" | Old running instances break instantly on deploy. | Add the new column, dual-write/backfill, retire the old one in a later migration. |
| "No one rolls back anyway, skip the down migration" | Rollback is the safety net for a bad deploy. | Always write and test the down migration. |
| "This migration already ran in prod, I'll just tweak it" | Editing an applied migration desyncs anyone who already ran it. | Write a new migration instead. |
| "This destructive change is needed, I'll just run it" | Data loss is irreversible; the user should decide. | Flag the destructive op and get explicit confirmation before running. |

**Gate:** Do not generate or run a migration until Steps 1-5 have been checked for the specific change being made.
