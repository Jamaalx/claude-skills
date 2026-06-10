---
description: "Supabase / Postgres health audit: missing indexes, slow queries via pg_stat_statements, unused indexes, table & index bloat, vacuum status, FK orphans, N+1 patterns in app code, table growth. Generates DB-FIXES.md with ready migrations."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# DATABASE HEALTH AUDIT

You are a Postgres / Supabase performance engineer. Goal: find structural problems that will cause this DB to slow down or break as data grows. Output a report + `DB-FIXES.md` with ready SQL migrations and code suggestions.

REQUIRED: resolve Supabase `project_id` from `.env*`. Confirm with the user.

---

## PHASE 1: TOPOGRAPHY

Use Supabase MCP:

- `list_tables` — every table, row count, size.
- Identify: hot tables (large or frequently queried), reference tables (small, joined often), append-only logs.
- Identify table-naming domains (e.g., `billing_*`, `auth_*`, `analytics_*`).

---

## PHASE 2: INDEX HEALTH

```sql
-- Missing indexes: large seq scans on big tables
SELECT relname, seq_scan, seq_tup_read, idx_scan, n_live_tup
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY seq_tup_read DESC
LIMIT 30;

-- Unused indexes (never scanned) — disk + write cost with no benefit
SELECT s.schemaname, s.relname AS table, s.indexrelname AS index,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size, s.idx_scan
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- Duplicate / overlapping indexes
SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS size,
       (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2
FROM (
  SELECT indexrelid::regclass AS idx, (indrelid::text || E'\n' || indclass::text || E'\n' || indkey::text || E'\n' || COALESCE(indexprs::text,''))
  FROM pg_index
) sub
GROUP BY 2
HAVING COUNT(*) > 1;

-- Tables likely missing an index on a frequent filter column:
-- Inspect from app code: grep ".eq(" / ".filter(" / "WHERE col" for each table and confirm an index exists.
```

For each finding, propose a `CREATE INDEX CONCURRENTLY ...` migration.

---

## PHASE 3: SLOW QUERIES

If `pg_stat_statements` extension is installed:

```sql
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

SELECT query, calls, total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

If not installed, suggest enabling it.

For top slow queries: get EXPLAIN ANALYZE plan, propose index or query rewrite.

---

## PHASE 4: BLOAT & VACUUM

```sql
SELECT relname, n_dead_tup, n_live_tup,
       round(100 * n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup,0), 1) AS dead_pct,
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname='public'
ORDER BY n_dead_tup DESC
LIMIT 20;
```

Flag tables with > 20% dead tuples and no recent autovacuum. Suggest manual `VACUUM ANALYZE` and/or tuning `autovacuum_vacuum_scale_factor`.

---

## PHASE 5: FOREIGN-KEY INTEGRITY

```sql
-- Tables with FKs
SELECT conrelid::regclass AS table, conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'public'::regnamespace;

-- Detect orphans (run per FK):
-- SELECT count(*) FROM child c LEFT JOIN parent p ON c.parent_id = p.id WHERE p.id IS NULL;
```

Flag tables without expected FKs (e.g., a `user_id` column with no FK to `auth.users`).

---

## PHASE 6: SCHEMA HYGIENE

```sql
-- Tables without primary key
SELECT n.nspname || '.' || c.relname AS table
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind='r' AND n.nspname='public'
  AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid=c.oid AND i.indisprimary);

-- Columns named *_id without index
-- (manual: cross-check columns ending in _id with pg_indexes)

-- Boolean / enum columns vs text with check constraint — prefer typed.

-- Timestamp columns without timezone (TIMESTAMP vs TIMESTAMPTZ) — flag.
```

---

## PHASE 7: APPLICATION-SIDE N+1 PATTERNS

Grep the codebase for patterns:

- A `for`/`map` loop over an array where each iteration calls `supabase.from(...).select(...)` → classic N+1.
- Sequential `await` inside loops on independent operations.
- Multiple `.from(...)` calls for the same row that could be one with select-with-relations.

For each, propose: batch via `.in('id', [...])`, or use Supabase relational select `select('*, related(*)')`, or `Promise.all`.

---

## PHASE 8: GROWTH & PARTITION READINESS

```sql
SELECT relname,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       pg_size_pretty(pg_relation_size(c.oid)) AS heap,
       n_live_tup
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE c.relkind='r' AND n.nspname='public'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 20;
```

Tables that already > 1M rows or growing fast: consider partitioning (by date for append-only logs, by tenant for multi-tenant).

---

## PHASE 9: SUPABASE-SPECIFIC

- `get_advisors` (security + performance) — include verbatim.
- `list_extensions` — anything unnecessary enabled? Anything missing that would help (`pg_stat_statements`, `pg_trgm` for text search)?
- `list_migrations` — anything pending or duplicated?
- Realtime publications — tables in `supabase_realtime` publication that don't need to be (perf cost).

---

## OUTPUT — REPORT

```
========================================
   DB HEALTH AUDIT REPORT
   Project: [name]   Supabase: [project_id]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[overall health rating + top 3 issues]

## CRITICAL (will break / is broken)
[orphan FKs, no PK, huge bloat, dangerous missing indexes on hot paths]

## HIGH (will degrade soon)
[missing indexes on frequently filtered columns, unbounded growth]

## MEDIUM (cleanup)
[unused indexes, duplicate indexes, vacuum tuning]

## LOW (nice-to-have)
[partition prep, type cleanup, naming consistency]

## TABLE INVENTORY
[markdown table: schema.table | rows | size | indexes | issues]

## TOP 20 SLOW QUERIES
[from pg_stat_statements]

## SUPABASE ADVISORS
[verbatim]

## AUDIT COVERAGE
```

---

## FIX KIT — write `DB-FIXES.md`

For each finding, generate either:

- A ready SQL migration (use `CREATE INDEX CONCURRENTLY` to avoid table locks, use `DROP INDEX CONCURRENTLY` for unused).
- A code-change prompt (for N+1 fixes), with file:line of the offending loop and the proposed batched version.
- A Supabase MCP command for `apply_migration`.

Each item:
```
### FIX-N: [title]
**Severity:** ...
**Type:** sql-migration | code | supabase-mcp | external-action
**Complexity:** quick | medium | complex

**SQL / change:**
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_<table>_<col> ON public.<table>(<col>);
```

**Verification:**
```sql
SELECT pg_size_pretty(pg_relation_size('idx_<table>_<col>'));
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM <table> WHERE <col> = '...';
```
```

Add `DB-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

---

## OPTIONAL: APPLY MIGRATIONS

If user confirms (`/db-health fix`), apply via Supabase MCP `apply_migration`. Use CONCURRENTLY for indexes. Stop on first failure.

START NOW.
