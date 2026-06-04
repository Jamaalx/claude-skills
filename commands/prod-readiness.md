---
description: "Fast pre-deploy checklist (<2 min): RLS on new tables, env vars present, build & typecheck pass, no PII in console.logs, service-role key not in client bundle, migrations pending vs applied, no debug routes. Stops obvious catastrophes before push."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, TaskCreate, TaskUpdate, "mcp__claude_ai_SupaBase__*"]
---

# PRE-DEPLOY READINESS CHECK

You are a release engineer running a fast gate before a production deploy. Goal: in under 2 minutes, catch the categories of mistakes that cause Sunday-night outages. Output: PASS / WARN / BLOCK with specific items.

This is a checklist, not a deep audit. Be fast. Be opinionated.

---

## CHECK 1: BUILD & TYPECHECK

- `npm run build` (or `pnpm build` / `yarn build`) must succeed.
- TypeScript: `npx tsc --noEmit` clean.
- Lint: `npm run lint` clean OR known-acceptable warnings only.

If any fails → BLOCK with the first error.

---

## CHECK 2: GIT STATE

- No uncommitted changes that look like secrets / `.env*` / credentials.
- Current branch tracks remote, no diverged commits without explanation.
- No commits with "wip", "fix me", "remove", "TODO" in the message in the last N commits being shipped.

---

## CHECK 3: ENV VARS

- Read `.env.example` (or equivalent). Every key listed there must exist in production env.
- For Railway / Hetzner / Vercel: list deployed env vars and diff against `.env.example`.
- Check no `NEXT_PUBLIC_` prefix on anything sensitive (service-role key, signing secret, DB URL).
- Check no env var value is literally `changeme`, `example`, `your-key-here`.

---

## CHECK 4: SERVICE-ROLE LEAKAGE (fast)

Grep:
- `"use client"` files importing anything that references `SUPABASE_SERVICE_ROLE_KEY`.
- `app/` and `pages/` top-level pages: no service-role imports.
- `public/` directory: no `.env` files, no secrets in any JSON/text.

BLOCK on any hit.

---

## CHECK 5: RLS COVERAGE

Via Supabase MCP `list_tables`:
- Every table in `public` schema must have `rls_enabled = true`.
- If any table is new vs the last known-deployed state (compare to migrations history or last git tag), verify RLS + policies exist.

BLOCK on any unprotected table.

---

## CHECK 6: MIGRATIONS

- `supabase/migrations/` (if exists) — any local migrations not yet applied?
- Via MCP `list_migrations` — pending vs applied.
- Any migration that does `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, or `ALTER COLUMN ... TYPE` on a large table → WARN, request explicit confirmation.

---

## CHECK 7: PII / SECRETS IN LOGS

Grep the code for:
- `console.log` / `console.error` containing variables named `password`, `token`, `key`, `secret`, `email`, `phone`, `cnp`, `iban`.
- Server logs that dump entire request bodies without redaction.

WARN with file:line list.

---

## CHECK 8: DEBUG / DEV-ONLY CODE

Grep:
- Routes named `/api/debug/*`, `/api/test/*`, `/api/admin/test/*` not guarded by env check.
- Code that does `if (process.env.NODE_ENV !== "production") { ... }` and contains a dangerous-looking branch.
- Hard-coded local URLs (`localhost`, `127.0.0.1`, `:3000`) in non-test code.
- `// TODO`, `// FIXME`, `// XXX` in code paths that are touched by this deploy.

---

## CHECK 9: DEPENDENCY SANITY

- `npm audit --audit-level=high --json` → any high/critical?
- Was `package-lock.json` modified without `package.json` changing in a way that makes sense?

WARN, not BLOCK, unless critical.

---

## CHECK 10: HEADERS & SECURITY MIDDLEWARE

For Next.js: `next.config.*` has `headers()` setting security headers (CSP, X-Frame-Options, Strict-Transport-Security)?
For Express/etc: `helmet` or equivalent in use?

WARN if missing.

---

## CHECK 11: HEALTHCHECK & MONITORING

- `/api/health` or equivalent endpoint exists and returns 200.
- Sentry / monitoring DSN configured for production.
- Error boundary set up in the app shell.

---

## CHECK 12: ROLLBACK PLAN

- Last successful deploy SHA known?
- Migrations are reversible OR there's a documented rollback procedure?
- DB has a backup younger than 24h?

---

## OUTPUT

```
========================================
   PROD READINESS REPORT
   Project: [name]   Date: [today]   Branch: [branch]
========================================

VERDICT: [GO / GO-WITH-WARNINGS / NO-GO]

## BLOCKERS (NO-GO)
[list with file:line / specific issue]

## WARNINGS (review before pushing)
[list]

## PASSED (12/12 checks)
[summary of what's clean]

## ACTION
[the single most important next step]
```

Be opinionated. If anything in CHECK 1, 4, or 5 fails, the verdict is NO-GO. Everything else is WARN.

Run all checks in parallel where possible. Total runtime target: under 2 minutes.
