# Auth & Session Audit — Fix Kit (EXAMPLE)
**Project:** acme-dashboard (fictional example)
**Audit date:** 2026-01-15
**Auth stack:** Supabase Auth (GoTrue) + @supabase/ssr, Next.js middleware
**Total findings:** 8 (1 CRITICAL, 3 HIGH, 3 MEDIUM, 1 LOW)

> This is a sanitized example of what `/auth-audit` produces. The real kit lands in your project root with concrete file:line references. After all FIX-N are applied & verified, delete with `rm AUTH-FIXES.md`.

---

## EXECUTIVE SUMMARY

Authentication uses Supabase Auth via cookies. The middleware pattern is correct. Two real attack paths exist for a developer with repo access and 20 minutes:

1. **Password leak via reset endpoint** — `POST /api/users/reset-password` returns the new password in the JSON body. Any admin who triggers a reset exposes the password in browser DevTools and reverse-proxy logs.
2. **Permission bypass at API layer** — `requireEdit(category)` is defined but never called from API routes. Editors blocked at the UI can still read data via direct `fetch()` calls.

There is no MFA, no login rate-limit, no self-service password reset.

---

## Execution Checklist

| # | Severity | Title | Type | Status |
|---|----------|-------|------|--------|
| FIX-1 | CRITICAL | Stop returning plaintext password in /users/reset-password response | code | [ ] |
| FIX-2 | HIGH | requireAuth uses .single() — switch to maybeSingle | code | [ ] |
| FIX-3 | HIGH | Wire requireView/requireEdit into category-gated API routes | code | [ ] |
| FIX-4 | HIGH | Add login rate-limit (per-IP + per-email) | code | [ ] |
| FIX-5 | MEDIUM | Tighten CSP: remove unsafe-inline / unsafe-eval from script-src | config | [ ] |
| FIX-6 | MEDIUM | Sign user out on password change to invalidate other sessions | code | [ ] |
| FIX-7 | MEDIUM | Log login / logout events to activity_log | code | [ ] |
| FIX-8 | LOW | Move rate-limit store off in-memory Map | code | [ ] |

---

## CRITICAL FIXES

### FIX-1: Stop returning plaintext password in /users/reset-password response
**Severity:** CRITICAL
**Type:** code
**Complexity:** quick (< 5 min)
**Files:** `src/app/api/users/reset-password/route.ts`

**Issue:**
The endpoint generates a new password and returns it in the response body:
```ts
return NextResponse.json({ success: true, password: newPassword, email: targetEmail });
```
The password lands in browser DevTools, reverse-proxy logs, browser-history extensions, and any screen-recording the admin runs.

**Prompt (paste into a fresh Claude Code session in this repo):**

> In `src/app/api/users/reset-password/route.ts`, the POST handler returns the new password in the JSON response. Remove that. Instead:
> 1. Use Supabase's `resetPasswordForEmail` to send a reset link to the user, OR generate a one-time reset token and email it.
> 2. The endpoint must only return `{ success: true, email: targetEmail }`.
> 3. Update any caller in `src/app/(dashboard)/settings/` that displays `data.password` — replace with a "Reset link sent to <email>" message.
> 4. Run `curl` to verify the response no longer contains `password`.

**Verification:**
- [ ] `grep -n "password:" src/app/api/users/reset-password/route.ts` shows no `password: newPassword` in `NextResponse`.
- [ ] Manual test as admin: network tab shows no password in response.

---

## HIGH FIXES

### FIX-2: requireAuth uses .single() — switch to maybeSingle
**Severity:** HIGH
**Type:** code
**Complexity:** quick
**Files:** `src/lib/api-auth.ts`

**Issue:**
`.single()` throws on 0 rows. A transient DB error makes `data` null → 403 for valid users. Multiple parallel API calls + one hiccup = "Forbidden" cascade across the whole dashboard.

**Prompt:**

> In `src/lib/api-auth.ts`, replace `.single()` with `.maybeSingle()` for the dashboard-users lookup. Capture the error separately:
> - On `error`: return 503 (transient, client retries).
> - On `data === null && error === null`: return 403 (truly not authorized).
> Run `npx tsc --noEmit` after.

**Verification:**
- [ ] `grep -n "\.single()" src/lib/api-auth.ts` returns nothing.

---

### FIX-3: Wire requireView/requireEdit into category-gated API routes
**Severity:** HIGH
**Type:** code
**Complexity:** medium
**Files:** every `src/app/api/**/route.ts` that returns category-specific data

**Issue:**
Permission helpers exist but no route calls them. Editors with `permissions = { customers: "none" }` see the UI hide that section, but `curl /api/customers` returns all rows.

**Prompt:**

> In `src/lib/api-auth.ts`, `requireView(user, category)` and `requireEdit(user, category)` are defined but never called from route handlers. For each route under `src/app/api/**/route.ts` that serves a categorized resource:
>
> 1. After `const auth = await requireAuth(); if (auth.error) return auth.error;`, add:
>    - For GET: `const v = requireView(auth.user, "<category>"); if (v) return v;`
>    - For POST/PATCH/PUT/DELETE: `const v = requireEdit(auth.user, "<category>"); if (v) return v;`
> 2. Categories are listed in `src/lib/permissions.ts`.
> 3. Admin-only routes (e.g. `/api/users/*`) keep their `role !== "admin"` check unchanged.
> 4. System routes (`/api/health`, cron) have no category — leave them.
> 5. Test as editor with `customers: "none"` — `curl /api/customers` must return 403.

**Verification:**
- [ ] `grep -rn "requireView\|requireEdit" src/app/api/` shows calls in handlers.
- [ ] Editor without view permission gets 403.

---

### FIX-4: Add login rate-limit (per-IP + per-email)
**Severity:** HIGH
**Type:** code
**Complexity:** medium

**(prompt body abbreviated for example — see full kit format in auth-audit.md)**

---

## MEDIUM FIXES

### FIX-5: Tighten CSP — remove unsafe-inline / unsafe-eval
**Severity:** MEDIUM
**Type:** config
**Files:** `next.config.ts`

**Issue:** `script-src 'self' 'unsafe-inline' 'unsafe-eval'` defeats XSS mitigation. Move to nonce-based CSP per Next.js docs.

---

### FIX-6: Sign user out on password change
**Severity:** MEDIUM
**Type:** code
**Files:** `src/app/(dashboard)/settings/page.tsx`

**Issue:** Other sessions remain valid after password change. Call `supabase.auth.signOut({ scope: "others" })` after success.

---

### FIX-7: Log login / logout events
**Severity:** MEDIUM
**Type:** code
**Files:** new `/api/auth/login`, `src/components/Sidebar.tsx`

**Issue:** `logActivity()` supports `login`/`logout` but is never called for them.

---

## LOW FIXES

### FIX-8: Move rate-limit store off in-memory Map
**Severity:** LOW
**Type:** code
**Files:** `src/lib/rate-limit.ts`

**Issue:** Single-instance state. On scale-out or restart, limits leak. Move to a Postgres/Upstash backend.

---

## EXTERNAL ACTIONS (Supabase Dashboard — cannot be automated)

| # | Severity | Action |
|---|----------|--------|
| EXT-1 | HIGH | Set Auth rate limits in project settings: Sign In 30/h, Sign Up 5/h |
| EXT-2 | MEDIUM | Enable TOTP MFA at project level |
| EXT-3 | MEDIUM | Restrict Allowed Redirect URLs to exact prod origins |

---

## WHAT'S GOOD

- `@supabase/ssr` cookie pattern correctly implemented.
- `getUser()` consistently used (no `getSession()`-only trust).
- Service role key isolated to server-only modules.
- `SERVICE_API_KEY` compared with `timingSafeEqual`.
- No `localStorage` token storage.
- Standard security headers set (X-Frame-Options DENY, HSTS preload, Referrer-Policy).

---

## Self-Destruct

After all items are checked off:
```
rm AUTH-FIXES.md
```
This file enumerates specific attack paths — never commit it. Already in `.gitignore`.
