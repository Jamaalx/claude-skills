# RLS & DB Authorization Audit — Fix Kit (EXAMPLE)
**Project:** acme-dashboard (fictional example)
**Supabase ref:** xxxxxxxxxxxxxxxxxxxx (sanitized)
**Audit date:** 2026-01-15
**Total findings:** 6 (2 CRITICAL, 2 HIGH, 1 MEDIUM, 1 LOW)

> This is a sanitized example of what `/rls-audit` produces. Real migrations land here as copy-paste SQL.

---

## EXECUTIVE SUMMARY

Of 24 public-schema tables, 22 have RLS enabled. **2 tables ship with RLS disabled** — anyone with the anon key reads them via PostgREST. One UPDATE policy on `profiles` allows users to write to their own `role` column — full privilege escalation in one request.

Service role key was not found in any client-side bundle (git history clean).

---

## Execution Checklist

| # | Severity | Title | Status |
|---|----------|-------|--------|
| FIX-1 | CRITICAL | Enable RLS on public.audit_log_external | [ ] |
| FIX-2 | CRITICAL | Block role column from user-writeable UPDATE policy on profiles | [ ] |
| FIX-3 | HIGH | Enable RLS on public.legacy_imports | [ ] |
| FIX-4 | HIGH | Tenant isolation on public.invoices (missing tenant_id check) | [ ] |
| FIX-5 | MEDIUM | Drop overly-permissive SELECT policy "public_read_all" on public.users_v2 | [ ] |
| FIX-6 | LOW | Add SECURITY DEFINER search_path to refresh_user_metrics() | [ ] |

---

## CRITICAL FIXES

### FIX-1: Enable RLS on public.audit_log_external
**Severity:** CRITICAL
**Type:** sql-migration
**Target:** `public.audit_log_external`

**Issue:** Table created by a migration in March without `ENABLE ROW LEVEL SECURITY`. Contains 47k rows of admin actions including emails. Anon key can read via PostgREST.

**SQL migration:**
```sql
-- migrations/20260115_enable_rls_audit_log_external.sql
ALTER TABLE public.audit_log_external ENABLE ROW LEVEL SECURITY;

-- Only the service role (or a defined admin role) should access this.
-- No policies = no access for anon / authenticated.
-- If admins should read via the app, add an explicit policy:

CREATE POLICY "admins_read_audit_log_external"
  ON public.audit_log_external
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dashboard_users
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

**Verification:**
```sql
-- Must show rowsecurity = true:
SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'audit_log_external';

-- As anon (in another session):
-- SELECT count(*) FROM public.audit_log_external; -- expect 0 or permission denied
```

---

### FIX-2: Block role column from user-writeable UPDATE policy on profiles
**Severity:** CRITICAL
**Type:** sql-migration
**Target:** `public.profiles`

**Issue:** Current UPDATE policy on `profiles` allows authenticated users to update their own row WITHOUT excluding the `role` column. A single request promotes self to admin:
```bash
PATCH /rest/v1/profiles?id=eq.<my-id> { "role": "admin" }
```

Current policy:
```sql
CREATE POLICY "users_update_own_profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
```

**SQL migration:**
```sql
-- Option A: column-level GRANT (cleanest)
REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (display_name, avatar_url, locale, bio) ON public.profiles TO authenticated;

-- Option B: tighten WITH CHECK to disallow role change
DROP POLICY "users_update_own_profile" ON public.profiles;
CREATE POLICY "users_update_own_profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
  );
```

**Verification:**
```sql
-- As a regular user:
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '<user-uuid>';
UPDATE public.profiles SET role = 'admin' WHERE id = '<user-uuid>';
-- must error or affect 0 rows
```

---

## HIGH FIXES

### FIX-3: Enable RLS on public.legacy_imports
**Severity:** HIGH
**Type:** sql-migration

**SQL migration:**
```sql
ALTER TABLE public.legacy_imports ENABLE ROW LEVEL SECURITY;
-- service role only; no policies needed for app users
```

---

### FIX-4: Tenant isolation on public.invoices
**Severity:** HIGH
**Type:** sql-migration
**Target:** `public.invoices`

**Issue:** Current SELECT policy: `USING (true)` — every user sees every tenant's invoices.

**SQL migration:**
```sql
DROP POLICY IF EXISTS "invoices_select_all" ON public.invoices;
CREATE POLICY "invoices_select_own_tenant" ON public.invoices
  FOR SELECT TO authenticated
  USING (
    tenant_id = (
      SELECT tenant_id FROM public.memberships
      WHERE user_id = auth.uid() LIMIT 1
    )
  );
```

**Verification:** as a user in tenant A, querying invoices returns 0 rows from tenant B.

---

## MEDIUM FIXES

### FIX-5: Drop overly-permissive SELECT policy on users_v2
**Severity:** MEDIUM
**Type:** sql-migration

**Issue:** Policy "public_read_all" allows anon to SELECT user emails. Likely intentional once for a public profile page but now stale.

**SQL migration:**
```sql
DROP POLICY "public_read_all" ON public.users_v2;
CREATE POLICY "users_v2_read_self_or_admin" ON public.users_v2
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.dashboard_users WHERE user_id = auth.uid() AND role = 'admin')
  );
```

---

## LOW FIXES

### FIX-6: Add SECURITY DEFINER search_path
**Severity:** LOW
**Type:** sql-migration

**Issue:** `refresh_user_metrics()` is `SECURITY DEFINER` without `SET search_path`. Vulnerable to search-path attacks if a privileged role schema is mutated.

**SQL migration:**
```sql
ALTER FUNCTION public.refresh_user_metrics() SET search_path = pg_catalog, public;
```

---

## TABLES STATUS

| Schema.Table | RLS | Policies | Verdict |
|--------------|-----|----------|---------|
| public.profiles | ON | 4 | FIX-2 |
| public.invoices | ON | 1 | FIX-4 |
| public.audit_log_external | OFF | 0 | FIX-1 |
| public.legacy_imports | OFF | 0 | FIX-3 |
| public.users_v2 | ON | 2 | FIX-5 |
| ... 19 others | ON | (varies) | OK |

---

## SERVICE ROLE EXPOSURE

CLEAN. No occurrences of `SUPABASE_SERVICE_ROLE_KEY` in any `"use client"` file or built bundle. Git history scanned 200+ commits — no leak.

---

## WHAT'S GOOD

- 22 of 24 tables have RLS enabled.
- All multi-tenant lookups (memberships, settings) correctly scope by `auth.uid()`.
- Service role isolated to server-only modules.
- No view in `public` schema runs `WITH (security_invoker = false)` against sensitive data.
- All `SECURITY DEFINER` functions validate the caller (except FIX-6).

---

## Self-Destruct

```
rm RLS-FIXES.md
```
