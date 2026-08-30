---
description: "Supabase RLS & Postgres authorization audit: unprotected tables, permissive policies, self-elevation vectors, SECURITY DEFINER, storage buckets, service-role leakage, multi-tenant isolation. Generates RLS-FIXES.md fix kit with ready migrations."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# RLS & DATABASE AUTHORIZATION AUDIT

You are a database-security engineer auditing the Supabase / Postgres authorization layer. Goal: prove that an attacker with only the `anon` or a regular-user JWT cannot read/write data outside their scope, and cannot escalate privileges by writing to role/permission columns.

Run ALL phases. Use Supabase MCP for live checks. Track with tasks. Output a report + write `RLS-FIXES.md` with ready-to-run SQL migrations.

REQUIRED: Supabase project must be identified. Read `.env*` for `NEXT_PUBLIC_SUPABASE_URL` and resolve `project_id` (subdomain of `*.supabase.co`). Confirm with the user before running any DDL.

---

## PHASE 1: RECONNAISSANCE

1. Resolve the Supabase project id from env.
2. List schemas in use: `public`, `auth`, `storage`, plus any custom.
3. Identify tables holding:
   - Auth / user / role / permission data
   - Customer-facing data (per-user or per-tenant)
   - Payment / financial data
   - PII (emails, phones, addresses)
   - Internal config / secrets
4. Identify the role/permission model:
   - Column on `auth.users.raw_user_meta_data`?
   - Separate table (`dashboard_users`, `profiles`, `memberships`)?
   - JWT custom claims via hook?

---

## PHASE 2: RLS STATUS — TABLE-BY-TABLE

```sql
-- Tables with RLS disabled in non-system schemas
SELECT n.nspname AS schema, c.relname AS table, c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','extensions','graphql','graphql_public','realtime','vault','net','pgsodium','pgsodium_masks','supabase_functions','supabase_migrations','_realtime','_analytics')
ORDER BY rls_enabled, schema, table;
```

For every table:
- RLS DISABLED in `public` → CRITICAL (anyone with anon key reads/writes via PostgREST).
- RLS ENABLED but NO policies → table is effectively locked out for anon (good for internal) but verify intent.
- RLS not FORCED → owner / `postgres` / service role still bypasses (expected, but be aware).

---

## PHASE 3: POLICY REVIEW

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname NOT IN ('pg_catalog','information_schema')
ORDER BY schemaname, tablename, policyname;
```

For each policy flag:

1. **`qual = 'true'` or `with_check = 'true'`** on a non-public-by-design table → CRITICAL.
2. **`roles = {public}` or `{anon}`** with read access to user/role/permission tables → CRITICAL.
3. **UPDATE policies allowing change to `role` / `is_admin` / `permissions` columns** → CRITICAL (self-elevation).
   - For each table with a role-ish column, verify there's no UPDATE policy that lets the user write to that column. Use column-level GRANT or check `with_check` excludes it.
4. **`cmd = 'ALL'` policies** are easy to over-trust; break them into per-operation policies where finer control is needed.
5. **Policies referencing `auth.uid()`** correctly? `auth.uid()` returns null for anon — a policy `USING (user_id = auth.uid())` with anon role allowed would let anon read rows where `user_id IS NULL`.
6. **Tenant isolation**: multi-tenant tables must check `tenant_id = (auth.jwt() ->> 'tenant_id')::uuid` or join through a membership table. Verify the JWT claim is actually set (check Auth Hook / custom claims).
7. **`WITH CHECK` present on INSERT/UPDATE/UPSERT** policies? Missing `WITH CHECK` on UPDATE lets a user move a row out of their scope.
8. **Policies that depend on a function** — read the function source and apply rules recursively.

---

## PHASE 4: PRIVILEGE ESCALATION VECTORS

For every table that has a `role`, `is_admin`, `permissions`, `tenant_id`, `org_id`, `owner_id`, `customer_id`, or similar authority-bearing column:

```sql
-- Show columns + any UPDATE policies on this table
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = '<TABLE>';

SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = '<TABLE>' AND cmd IN ('UPDATE','ALL');
```

Specifically check:

- Is there a way for a logged-in user to set `role = 'admin'` on their own row?
- Is there a way to insert a new row that gives them admin?
- Is there a SECURITY DEFINER function that takes a `role` argument and writes it?
- Is there a trigger that copies `raw_user_meta_data.role` from signup payload? (User-controlled at signup!)

---

## PHASE 5: SECURITY DEFINER FUNCTIONS

```sql
-- Lists secdef functions AND answers the two questions that matter directly:
-- who can execute them, and whether search_path is pinned.
SELECT n.nspname AS schema,
       p.proname AS func,
       pg_get_function_arguments(p.oid) AS args,
       -- who can execute: NULL proacl = implicit PUBLIC EXECUTE (so anon too)
       COALESCE(array_to_string(p.proacl, ', '), '(PUBLIC — implicit)') AS grants,
       (p.proacl IS NULL
        OR array_to_string(p.proacl, ',') LIKE '%anon=X%')            AS anon_can_execute,
       COALESCE(array_to_string(p.proconfig, ', '), '(none)')          AS settings,
       (p.proconfig IS NULL
        OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c
                       WHERE c LIKE 'search_path=%'))                  AS search_path_unpinned
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','auth')
  AND p.prosecdef
ORDER BY anon_can_execute DESC, search_path_unpinned DESC, schema, func;
```

The sort puts the dangerous ones first. `anon_can_execute = true` means anyone holding the anon key
— which is **public, it ships in the browser bundle** — can call the function via
`POST /rest/v1/rpc/<name>`. This is not theoretical: confirm it with a real curl, don't assume.

For each SECURITY DEFINER function:
- Read the source (`pg_get_functiondef(oid)`).
- Does it validate the caller (e.g., check `auth.uid()`, role)?
- Does it use `SET search_path = pg_catalog, public` to prevent search-path attacks?
- Does it grant access to data that the caller's RLS would otherwise hide?
- Is it exposed via PostgREST (RPC)? `GRANT EXECUTE` to `anon` / `authenticated`?

### 5a. Tenant-from-payload — the easiest pattern to miss

`SECURITY DEFINER` bypasses RLS **by definition**, and foreign keys between tables do not check the
tenant. So a function shaped like `fn_x(p_tenant_id uuid, p_some_id uuid, ...)` that **trusts its
arguments** is a cross-tenant hole even when it filters on them correctly — because the caller
chooses what to send.

For every secdef function, ask: **where does the tenant come from?**
- ❌ from a parameter (`p_tenant_id`) → anyone can pass a different tenant;
- ✅ from claims (`fn_tenant_id()` / `auth.jwt()`), with `RAISE EXCEPTION` when NULL;
- ✅ and every **id received** validated with `EXISTS` as belonging to that tenant — not just the tenant itself.

A related second pattern: functions that are **oracles**, not just readers. A PIN/code/token check
exposed as RPC is brute-forceable indefinitely; the application's rate limit **does not apply** when
the attacker hits the RPC directly. A 4-digit PIN is 10,000 attempts.

### 5b. Policy performance (not security, but it costs you)

RLS runs **per row**. Two checks, both from Supabase's own guidance:
- **An index on every column a policy filters by** (typically `tenant_id`, `user_id`). Without one,
  every query becomes a full scan. Indexed, RLS typically adds under 5 ms.
- **`auth.uid()` wrapped in a subquery**: `(select auth.uid())` rather than bare `auth.uid()` —
  otherwise it is re-evaluated for every row instead of once.

```sql
-- Columns a policy filters on, with no index STARTING with them.
-- Ordered by table size: that's where it hurts first.
SELECT c.relname AS table_name, a.attname AS column_name,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS size
FROM pg_policy pol
JOIN pg_class c ON c.oid = pol.polrelid
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE pg_get_expr(pol.polqual, pol.polrelid) ~ ('\m' || a.attname || '\M')
  AND NOT EXISTS (                       -- indkey[0] = the index's LEADING column;
    SELECT 1 FROM pg_index i             -- an index (x, tenant_id) does NOT help a policy on tenant_id
    WHERE i.indrelid = c.oid AND a.attnum = i.indkey[0]
  )
GROUP BY c.relname, a.attname, c.oid
ORDER BY pg_total_relation_size(c.oid) DESC;
```

Two details that separate a useful query from noise, both verified against a real database:
- **`~ '\m...\M'` (whole word), not `LIKE '%...%'`** — otherwise a column named `id` matches any
  expression containing `tenant_id`, and you drown in false positives.
- **`i.indkey[0]`, not `ANY(i.indkey)`** — a composite index `(created_at, tenant_id)` does not help a
  policy filtering on `tenant_id`; the column has to be **leading**.

---

## PHASE 6: GRANTS & ROLE PRIVILEGES

```sql
-- What anon and authenticated can touch
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('anon','authenticated')
ORDER BY grantee, table_schema, table_name;

-- Column-level grants (rare but check)
SELECT grantee, table_schema, table_name, column_name, privilege_type
FROM information_schema.role_column_grants
WHERE grantee IN ('anon','authenticated')
ORDER BY grantee, table_schema, table_name, column_name;

-- Sequence access (can let an attacker drain ID space)
SELECT grantee, object_schema, object_name, privilege_type
FROM information_schema.role_usage_grants
WHERE grantee IN ('anon','authenticated');
```

Flag any unexpected `INSERT/UPDATE/DELETE` grants to `anon`.

---

## PHASE 7: STORAGE BUCKETS

```sql
SELECT id, name, public, file_size_limit, allowed_mime_types FROM storage.buckets;
```

For each `public = true` bucket: confirm intentional (e.g., marketing images). Sensitive buckets must be private and gated by a storage RLS policy in `storage.objects`.

```sql
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE schemaname='storage' AND tablename='objects';
```

Verify each bucket has policies that restrict by `owner = auth.uid()` or path prefix matching the user / tenant.

---

## PHASE 8: SERVICE-ROLE LEAKAGE

The single most damaging finding. Grep:

1. Project codebase:
   - `SUPABASE_SERVICE_ROLE_KEY` referenced ONLY in server-side files (no `"use client"`, no `app/.../page.tsx` top-level, no `components/`).
   - No `process.env.SUPABASE_SERVICE_ROLE_KEY` inside any file imported by a client component.
   - No service-role key in `next.config.*` exposed via `env` or `publicRuntimeConfig`.
   - `.env*` not committed (also covered by `/security-audit` phase 3 — confirm here).
2. Git history:
   - `git log --all -p -- '*.env*' | grep -i service_role` → must be empty.
3. Built bundle (if `.next/` exists):
   - `grep -r "service_role" .next/static/` → must be empty.
4. Cloudflare / Railway env vars: confirm service role is server-only (no `NEXT_PUBLIC_` prefix).

A leaked service role bypasses RLS entirely — finding it is the speedrun.

---

## PHASE 9: VIEWS, MATERIALIZED VIEWS, EXTENSIONS

```sql
SELECT schemaname, viewname, viewowner FROM pg_views WHERE schemaname='public';
SELECT schemaname, matviewname, matviewowner FROM pg_matviews WHERE schemaname='public';
```

Views in Postgres inherit the privileges of the view OWNER, not the caller — they can bypass RLS. Each public-schema view must either be locked down by grants or by being defined `WITH (security_invoker = true)` (PG 15+) so it inherits caller RLS.

```sql
SELECT name, installed_version, schema FROM pg_extension JOIN pg_namespace n ON n.oid = pg_extension.extnamespace JOIN pg_available_extensions a ON a.name = pg_extension.extname;
```

Flag dangerous extensions enabled without need: `dblink`, `postgres_fdw`, `pg_net`, `http`, `plperlu`, `plpython3u`.

---

## PHASE 10: SUPABASE ADVISORS

If MCP available:

- `mcp__claude_ai_SupaBase__get_advisors` → include its findings verbatim in the report (it already catches `auth_rls_initplan`, `policy_exists_rls_disabled`, etc.).

---

## PHASE 11: REALTIME, BROADCAST, PRESENCE

If Supabase Realtime is used:
- Verify Realtime channels have RLS via the `realtime.messages` table policies (Supabase Realtime v2).
- Verify subscriptions to tables propagate RLS correctly — a row that RLS hides from a user must NOT be sent over the websocket.
- Test by subscribing as anon and confirming no sensitive rows arrive.

---

## PHASE 12: LIVE PROBE (with confirmation)

If the user confirms, run a non-destructive probe:

- With anon key: `select count(*) from <each_table>` via REST → expect 0 / 401 for protected tables.
- With a regular-user JWT (user supplies one): try to update `role` on their own profile row → expect rejection.
- Try insert into a tenant-scoped table with a different `tenant_id` → expect rejection.

NEVER run write probes without the user's explicit greenlight on a non-production project.

---

## OUTPUT — REPORT

```
========================================
   RLS / DB AUTHORIZATION AUDIT REPORT
   Project: [name]   Supabase ref: [project_id]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Risk rating + can an authenticated user become admin? yes/no — and how]

## CRITICAL / HIGH / MEDIUM / LOW FINDINGS
[Each finding: schema.table[.column], policy/grant excerpt, attack scenario, fix SQL, severity]

## TABLES STATUS
[Markdown table: schema.table | RLS enabled | # policies | verdict]

## ROLE / PERMISSION INTEGRITY
[Can a user escalate? where? how?]

## SERVICE ROLE EXPOSURE
[Clean / leak found at file:line]

## SUPABASE ADVISORS
[Verbatim list]

## WHAT'S GOOD
[Tables / policies that are correctly hardened]

## AUDIT COVERAGE
[Phases run / skipped]
```

---

## FIX KIT — write `RLS-FIXES.md`

Generate ready-to-apply migrations and configuration changes, ordered CRITICAL → LOW.

Each fix:

```
### FIX-N: [title]
**Severity:** ...
**Type:** sql-migration | code | external-action | supabase-mcp
**Complexity:** quick | medium | complex
**Target:** schema.table or file path

**SQL migration (ready to apply):**
```sql
-- migrations/[timestamp]_[slug].sql
ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;
CREATE POLICY "..." ON public.<table>
  FOR SELECT TO authenticated USING (<condition>);
-- ... etc
```

**Prompt (alternative — for a Claude Code session):**
> [Self-contained instruction; can be executed by an agent that has Supabase MCP and project access. State expected before/after, verification query.]

**Verification:**
```sql
-- After apply, this must return 0 rows for the attack case:
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '<some-user-id>';
SELECT count(*) FROM public.<table> WHERE <condition that should be denied>;
```
```

Write the kit to `RLS-FIXES.md` in project root. Add `RLS-FIXES.md` to `.gitignore`. Include checklist table at the top. Include self-destruct note (`rm RLS-FIXES.md`) at the bottom.

---

## OPTIONAL: APPLY MIGRATIONS

If the user explicitly approves (`/rls-audit fix` argument or follow-up confirmation), iterate through the fix kit:

- For each `sql-migration` fix, call `mcp__claude_ai_SupaBase__apply_migration` with a snake_case name.
- Check off the item in `RLS-FIXES.md`.
- After each apply, run the verification query from that fix.
- STOP and ask if any verification fails.

NEVER apply DDL on a project that the user has not explicitly approved for live changes. Default behavior is: write the kit and stop.

START NOW. Use parallel agents for the per-table policy review when many tables exist.
