---
description: "Safety review of pending Supabase / Postgres migrations: destructive ops, locking impact on large tables, missing IF NOT EXISTS, reversibility, RLS still enabled after, data-loss risk. Generates MIGRATION-FIXES.md with safer rewrites."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, TaskCreate, TaskUpdate, "mcp__claude_ai_SupaBase__*"]
---

# MIGRATION SAFETY AUDIT

You are a database release engineer reviewing one or more pending migrations before they are applied to production. Goal: prevent table locks that take down the app, silent data loss, and accidentally disabled RLS.

---

## PHASE 1: INVENTORY

Identify pending migrations:

- Local `supabase/migrations/*.sql` not yet in `list_migrations` (via MCP), or `supabase migration list` / `supabase db push --dry-run` (CLI).
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
- `ALTER TABLE ... SET NOT NULL` without a backfill step (it also scans the whole table under ACCESS EXCLUSIVE — see Phase 3)
- `DELETE FROM` / `UPDATE` without a `WHERE` (or with a sketchy WHERE)
- `REINDEX` not CONCURRENTLY
- Renaming a column / table used by application code without a coordinated deploy

For each: estimate row count via `mcp__claude_ai_SupaBase__execute_sql` (`SELECT count(*) FROM ...`) and table size.

---

## PHASE 3: LOCK IMPACT

For each `ALTER`/`CREATE`/`DROP`, classify the lock level:

- `ACCESS EXCLUSIVE` (blocks reads + writes): most `ALTER TABLE` forms. Duration is what matters:
  - with a **table rewrite** (long): `ADD COLUMN ... DEFAULT <volatile>` (e.g. `clock_timestamp()`, `gen_random_uuid()`), stored generated / identity column, `ALTER COLUMN TYPE` (unless binary-coercible, e.g. `varchar`→`text`), `SET NOT NULL` (full scan, no rewrite).
  - **metadata-only** (instant): `ADD COLUMN` nullable or with a non-volatile default (PG 11+), `DROP COLUMN`, `ADD CONSTRAINT ... NOT VALID`.
- `SHARE ROW EXCLUSIVE` (blocks writes) on BOTH tables: `ADD FOREIGN KEY` (validated immediately unless `NOT VALID`).
- `SHARE` (blocks writes): `CREATE INDEX` (without CONCURRENTLY).
- `SHARE UPDATE EXCLUSIVE` (reads + writes continue): `CREATE INDEX CONCURRENTLY`, `VALIDATE CONSTRAINT`.

Even an instant ACCESS EXCLUSIVE op is dangerous if it has to **wait**: while it queues behind a long-running query, every later query on that table queues behind it. Every migration touching a hot table should start with `SET lock_timeout = '3s';` (fail fast, retry) — not set globally in `postgresql.conf`.

For tables > 100k rows: any ACCESS EXCLUSIVE op needs to be rewritten:
- `ADD COLUMN nullable + backfill in batches + NOT NULL` instead of single shot. For the NOT NULL step: PG 18+ `ADD CONSTRAINT <name> NOT NULL <col> NOT VALID` then `VALIDATE CONSTRAINT <name>`; on PG <= 17 add `CHECK (<col> IS NOT NULL) NOT VALID`, `VALIDATE` it, then `SET NOT NULL` skips the scan (drop the CHECK after). Check the server version (`select version()`) — hosted Supabase may not be on 18 yet.
- `CREATE INDEX CONCURRENTLY` always. It **cannot run inside a transaction block** — check whether your migration runner wraps each file in a transaction; if so, isolate it. A failed concurrent build leaves an `INVALID` index that still costs writes: drop it (`DROP INDEX CONCURRENTLY`) before retrying.
- `ADD CONSTRAINT ... NOT VALID` then `VALIDATE CONSTRAINT` for FK / CHECK (PG 18 also allows `NOT VALID` FKs on partitioned tables)

References: [ALTER TABLE (PG 18)](https://www.postgresql.org/docs/18/sql-altertable.html), [CREATE INDEX](https://www.postgresql.org/docs/18/sql-createindex.html), [lock_timeout](https://www.postgresql.org/docs/18/runtime-config-client.html), [PG 18 release notes](https://www.postgresql.org/docs/release/18.0/).

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
- Explicit `GRANT`s for the roles that should reach the table via the Data API (`anon` read-only only if public by design; `authenticated` / `service_role` as needed)? Supabase stopped auto-granting new `public` tables (new projects from 2026-05-30, all projects from 2026-10-30) — no grant means `42501 permission denied` before RLS is even evaluated. ([changelog](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically))
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
- Migration enables a new extension? Confirm available on Supabase and not in deny list; install into `extensions`, not `public` (advisor `extension_in_public`).
- After applying (branch / staging first), run `get_advisors` (security + performance) and treat new ERROR-level lints as a regression of this migration.

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
- ADD COLUMN nullable + backfill + NOT NULL (`NOT VALID` + `VALIDATE`) split
- `SET lock_timeout` at the top of each migration touching a hot table
- ADD CONSTRAINT NOT VALID + VALIDATE split
- Pre/post verification queries
- Application code change coordination notes

Add `MIGRATION-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

---

## OPTIONAL: APPLY

Only on explicit confirmation. Apply each migration via `mcp__claude_ai_SupaBase__apply_migration`, run verification query, stop on failure.

START NOW.
