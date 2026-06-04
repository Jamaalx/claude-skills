---
description: "Safety review of pending Supabase / Postgres migrations: destructive ops, locking impact on large tables, missing IF NOT EXISTS, reversibility, RLS still enabled after, data-loss risk. Generates MIGRATION-FIXES.md with safer rewrites."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, TaskCreate, TaskUpdate, "mcp__claude_ai_SupaBase__*"]
---

# MIGRATION SAFETY AUDIT

You are a database release engineer reviewing one or more pending migrations before they are applied to production. Goal: prevent table locks that take down the app, silent data loss, and accidentally disabled RLS.

---

## PHASE 1: INVENTORY

Identify pending migrations:

- Local `supabase/migrations/*.sql` not yet in `list_migrations` (via MCP).
- Files modified in current git diff against main.
- If user provides a specific migration file or block, audit only that.

For each pending migration, read the full SQL.

---

## PHASE 2: DESTRUCTIVE OPERATION SCAN

Flag any of these with CRITICAL severity unless explicitly justified in a comment:

- `DROP TABLE` (without `IF EXISTS`, or any drop of a table with data)
- `DROP COLUMN` (data lost; coordinate with app deploy)
- `DROP INDEX` not `CONCURRENTLY` on a hot table
- `TRUNCATE`
- `ALTER COLUMN ... TYPE` (full table rewrite, locks table for the duration)
- `ALTER TABLE ... SET NOT NULL` without a backfill step
- `DELETE FROM` / `UPDATE` without a `WHERE` (or with a sketchy WHERE)
- `REINDEX` not CONCURRENTLY
- Renaming a column / table used by application code without a coordinated deploy

For each: estimate row count via `mcp__claude_ai_SupaBase__execute_sql` (`SELECT count(*) FROM ...`) and table size.

---

## PHASE 3: LOCK IMPACT

For each `ALTER`/`CREATE`/`DROP`, classify the lock level:

- `ACCESS EXCLUSIVE` (blocks reads + writes): `ALTER TABLE ADD COLUMN ... DEFAULT non_constant`, `ALTER COLUMN TYPE`, `DROP COLUMN`, `ADD CONSTRAINT NOT VALID` (small) then `VALIDATE CONSTRAINT` (long but no AccessExclusive).
- `SHARE` (blocks writes): `CREATE INDEX` (without CONCURRENTLY).
- `ACCESS SHARE` (no real impact): most `CONCURRENTLY` ops.

For tables > 100k rows: any ACCESS EXCLUSIVE op needs to be rewritten:
- `ADD COLUMN nullable + backfill in batches + SET NOT NULL` instead of single shot
- `CREATE INDEX CONCURRENTLY` always
- `ADD CONSTRAINT ... NOT VALID` then `VALIDATE CONSTRAINT` for FK / CHECK

Propose rewrites in the fix kit.

---

## PHASE 4: IDEMPOTENCY & REVERSIBILITY

- Every `CREATE TABLE` / `CREATE INDEX` / `CREATE TYPE` should use `IF NOT EXISTS` (or be guaranteed run-once via migration framework).
- Every `DROP` should use `IF EXISTS` to avoid breaking re-runs.
- Is there a rollback / down migration? If using Supabase migrations, the convention is forward-only — note the inverse migration to write if reverting.

---

## PHASE 5: RLS PRESERVATION

After each migration:

- New tables: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` present?
- Policy `CREATE` paired with the new table?
- Old policies still apply after rename / column drop?

Cross-check via post-apply query (in the fix kit verification):

```sql
SELECT tablename FROM pg_tables WHERE schemaname='public'
AND tablename = '<new_table>' AND rowsecurity = false;
-- must return 0 rows
```

---

## PHASE 6: DATA SAFETY

- `UPDATE` and `DELETE`: estimate affected row count; if > 1000, batch.
- Transactions: long-running `BEGIN ... COMMIT` blocks lock acquisition order — confirm the script doesn't acquire conflicting locks.
- Triggers / RLS interaction: any new trigger that recursively writes to the same table?

---

## PHASE 7: APPLICATION COMPATIBILITY

For each schema change:

- Grep the codebase for the affected table / column name.
- Will the app crash if the migration is applied before code deploy? (e.g., column dropped → SELECT * still works but `INSERT (col)` fails).
- Order of operations for zero-downtime:
  - Add new column → deploy code that writes both → migrate data → deploy code that reads new only → drop old column.
- If app is single-tenant low-traffic, document acceptable downtime instead.

---

## PHASE 8: SUPABASE-SPECIFIC

- Migration touches `auth.*` tables? Discouraged; use Auth Hooks or custom tables.
- Migration uses `SECURITY DEFINER` functions? Verify `SET search_path = pg_catalog, public`.
- Migration enables a new extension? Confirm available on Supabase and not in deny list.

---

## OUTPUT — REPORT

```
========================================
   MIGRATION SAFETY AUDIT
   Pending migrations: [count]   Date: [today]
========================================

## VERDICT
[GO / GO-WITH-CHANGES / NO-GO]

## CRITICAL ISSUES
[per-migration list]

## HIGH (lock impact, data risk)

## MEDIUM (idempotency, missing IF EXISTS)

## LOW (style, comments)

## PER-MIGRATION SUMMARY
| File | Operations | Lock level | Affected rows | Verdict |
|------|------------|------------|---------------|---------|

## REWRITES PROPOSED
[Counts; details in FIX KIT]
```

---

## FIX KIT — write `MIGRATION-FIXES.md`

For each problematic migration, provide a rewritten safer version with:

- CONCURRENTLY for index ops
- Batched UPDATE/DELETE
- ADD COLUMN nullable + backfill + SET NOT NULL split
- ADD CONSTRAINT NOT VALID + VALIDATE split
- Pre/post verification queries
- Application code change coordination notes

Add `MIGRATION-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

---

## OPTIONAL: APPLY

Only on explicit confirmation. Apply each migration via `mcp__claude_ai_SupaBase__apply_migration`, run verification query, stop on failure.

START NOW.
