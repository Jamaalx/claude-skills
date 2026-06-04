---
description: "Full auth & session audit: login flow, session/cookie security, JWT handling, middleware safety, privilege escalation, MFA, audit logging, rate limiting. Generates AUTH-FIXES.md fix kit."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# AUTH & SESSION SECURITY AUDIT

You are a senior application-security engineer performing a focused audit on the authentication, session, and authorization layer of this project. Be paranoid. Assume a developer with read access to the repo and ~15-20 minutes can attempt privilege escalation — your job is to make that impossible.

Run ALL phases below. Use parallel agents where independent. Track progress with tasks. At the end, write `AUTH-FIXES.md` to the project root (and `.gitignore` it) with copy-paste-ready fix prompts ordered by severity.

---

## PHASE 1: RECONNAISSANCE

1. Identify the auth stack:
   - Supabase Auth (GoTrue), Auth.js / NextAuth, Lucia, Clerk, Firebase, custom, etc.
   - Cookie-based session vs JWT-in-storage vs hybrid
   - SSR/middleware (Next.js middleware, Express, etc.)
2. Locate every file involved in auth:
   - login / signup / logout / password reset / magic link / OAuth callback
   - middleware (route protection)
   - server-side auth helpers (`requireAuth`, `getSession`, etc.)
   - client-side auth client (browser supabase client, Auth.js useSession, etc.)
   - admin / role-elevation flows
3. Identify all roles, permissions, and where they are stored (DB column, JWT claim, separate table).

---

## PHASE 2: SESSION & COOKIE SECURITY

Check every cookie set by the app:

- `HttpOnly` set? (must be true for session cookies)
- `Secure` set? (must be true in production)
- `SameSite=Lax` or `Strict`? (`None` only with explicit reason)
- `Path` not overly broad
- `Domain` not set to a parent domain unnecessarily
- Expiry / Max-Age sane (not multi-year unless intentional)
- Session ID / token entropy >= 128 bits

Check session lifecycle:

- Session regenerated after login (prevent session fixation)?
- Server-side session invalidation on logout? (not just cookie delete)
- Concurrent session policy (allow / cap / single)?
- Idle timeout / absolute timeout configured?
- Session cookie scoped correctly to subdomain rules?

For Supabase / @supabase/ssr:

- `createServerClient` and `createBrowserClient` properly separated?
- `getUser()` used for validation (NOT `getSession()` alone)?
- Cookies refreshed correctly in middleware (`supabaseResponse` rebuilt on `setAll`)?
- No mixing of client/server clients in the same module.

---

## PHASE 3: LOGIN FLOW

- Rate limiting on login endpoint? (`@upstash/ratelimit`, `next-rate-limit`, custom). Per-IP AND per-account.
- Brute-force lockout after N failed attempts?
- Constant-time password comparison (bcrypt / argon2 / scrypt — never MD5/SHA1/plain)?
- Generic error message (don't leak "user does not exist" vs "wrong password")?
- CAPTCHA / hCaptcha / Turnstile on repeated failures or signup?
- Email enumeration protection on signup, password reset, OAuth link.
- Login response: no PII, no JWT in body for cookie-based flows.
- Redirect after login validates `redirectTo` against allowlist (open-redirect check).
- Login form CSRF-protected (token / SameSite cookie / Origin check).

---

## PHASE 4: LOGOUT & SESSION TERMINATION

- Server-side: refresh token revoked / session row deleted / JWT denylisted?
- Client clears local state (React state, localStorage, IndexedDB)?
- Logout endpoint requires POST (not GET) so it can't be triggered by `<img src>`?
- "Logout everywhere" / sign-out-other-sessions available for sensitive apps?

---

## PHASE 5: TOKEN HANDLING

- Service role / admin keys NEVER in client bundle. Grep every `"use client"` file and `public/` for service-role patterns.
- No JWT in `localStorage` / `sessionStorage` if using cookie sessions (XSS risk).
- API tokens (SERVICE_API_KEY etc.) compared with constant-time function (`timingSafeEqual`), not `===`.
- JWTs (if used) signed with strong secret (>= 256 bits), no `alg: none`, expiration enforced.
- Refresh tokens: rotation enabled, reuse-detection (replay = revoke family).
- Tokens not logged anywhere (console, file logs, error trackers).

---

## PHASE 6: AUTHORIZATION & PRIVILEGE ESCALATION

The 15-minute-speedrun checklist. Be ruthless here.

1. **Role storage**: where is `role` / `is_admin` stored? Can the user UPDATE that field via:
   - Direct REST call to Supabase with their JWT (if RLS lets them update own row)?
   - An upsert on a related table?
   - Profile / preferences endpoint that accepts a `role` field?
2. **Mass assignment**: any endpoint that takes a body object and spreads it into `update(...)`? Look for `{...req.body}`, `Object.assign(row, body)`, `supabase.update(body)`.
3. **IDOR**: every endpoint with `id` in URL or body — does it verify the resource belongs to the user? Grep for `.eq("id", ...)` without `.eq("user_id", auth.user.id)`.
4. **Permission check coverage**: every API route under `app/api/**` and every server action must call `requireAuth` (and `requireEdit` / role check for mutations). List endpoints that DON'T.
5. **Admin-only routes**: do they actually check `role === 'admin'`? Or just `requireAuth`?
6. **Middleware bypass**: if route-protection is in middleware, can a path be crafted to evade the matcher (`/api/` vs `/api`, trailing slash, encoded chars)?
7. **Frontend-only checks**: any feature that's "hidden" only by UI conditional but the underlying API endpoint accepts the request unauthenticated.
8. **GraphQL / tRPC**: introspection disabled in prod? Every procedure has `protectedProcedure` / auth middleware?

---

## PHASE 7: PASSWORD RESET / MAGIC LINK / OAUTH

- Password reset token: single-use, short TTL (<= 1h), bound to user, invalidated after use.
- Reset link not logged or sent over insecure channel.
- After reset, ALL existing sessions invalidated.
- Magic link: single-use, TTL <= 15min, signed/HMAC'd, bound to email.
- OAuth callback validates `state` parameter (CSRF).
- OAuth scope minimal; PKCE used for public clients.
- Account linking does not allow takeover via unverified email match.

---

## PHASE 8: MIDDLEWARE SAFETY

The fragile-middleware checklist (this is where users get randomly logged out and where transient failures cascade):

- `.single()` on auth-related lookups → switch to `.maybeSingle()` and handle error separately. A query failure must NOT trigger `signOut()`.
- No destructive `auth.signOut()` from middleware on transient DB errors.
- Cookies refreshed in middleware (`@supabase/ssr` pattern: rebuild `supabaseResponse` inside `setAll`).
- `getUser()` runs only where needed (skip static assets, optionally skip pure-public routes).
- Multiple parallel requests with expired access token: does refresh-token rotation create races? If yes, document or use reuse interval.
- Middleware does not depend on optional services (no auth lookup against a flaky 3rd-party API).

---

## PHASE 9: MFA & STEP-UP

- MFA available for admin accounts? (TOTP, WebAuthn / passkeys)
- Sensitive operations (delete account, change email, change role) require re-auth or step-up?
- Recovery codes generated, displayed once, stored hashed?

---

## PHASE 10: AUDIT LOGGING

- Are auth events logged with timestamp, IP, user-agent, outcome?
  - login success / failure
  - password change
  - role change
  - MFA enable/disable
  - email change
  - permission grant
  - logout
- Log destination not world-readable. PII redaction in logs (no passwords, no tokens, IPs only if needed for security).
- Logs queryable for incident response.
- Retention policy defined.

For Supabase: check `auth.audit_log_entries` is populated and accessible; consider mirroring critical events into a `dashboard_audit_log` table.

---

## PHASE 11: RATE LIMITING & ABUSE

- Login: per-IP and per-account.
- Password reset: per-account and per-email.
- Signup: per-IP, anti-disposable-email if relevant.
- Any auth endpoint: 429 with `Retry-After` header.
- Sliding-window or token-bucket; not memory-only on multi-instance (use Redis / Upstash / DB).

---

## PHASE 12: LIVE INFRASTRUCTURE (Supabase MCP if available)

Run these queries to fact-check the audit:

```sql
-- Users with admin role
SELECT id, email, role, created_at FROM auth.users u
JOIN <your_role_table> r ON r.user_id = u.id
WHERE r.role = 'admin';

-- Sessions never expiring
SELECT count(*) FROM auth.sessions WHERE not_after IS NULL;

-- Recently failed auth attempts (brute force indicator)
SELECT payload->>'actor_username' AS who, count(*)
FROM auth.audit_log_entries
WHERE created_at > now() - interval '7 days'
  AND payload->>'action' IN ('login_failed','user_signedup_failed')
GROUP BY 1 ORDER BY 2 DESC LIMIT 20;

-- Functions that bypass RLS
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public' AND security_type = 'DEFINER';
```

Also check Supabase Auth project settings (note these in the report; cannot read via SQL):

- JWT expiry (recommend 3600s for app, longer if cookie-based with refresh)
- Refresh token rotation: enabled
- Refresh token reuse interval: 10s default ok
- Session timebox / inactivity: set if needed
- Allowed redirect URLs: tight
- Email confirmation required
- Password min length and strength rules
- MFA enabled at project level

---

## PHASE 13: RUNTIME PROBE (optional, only on confirmation)

If the user confirms, perform safe live checks against the running app:

- `curl` an admin-only endpoint with no auth header → expect 401/403.
- `curl` an admin-only endpoint with a regular-user JWT → expect 403.
- Login attempt with wrong password 20x → expect lockout / 429.
- POST to `/api/.../target` with another user's resource id → expect 403.
- Inspect Set-Cookie headers on login response.

NEVER run aggressive probes (DoS, mass enum) without explicit written approval.

---

## OUTPUT — REPORT

Produce a structured report identical in spirit to `/security-audit`:

```
========================================
   AUTH & SESSION AUDIT REPORT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Risk rating + 2-3 sentence verdict on attacker's 20-min speedrun feasibility]

## CRITICAL / HIGH / MEDIUM / LOW FINDINGS
[Each finding: file:line, attack scenario, fix, severity]

## SUPABASE AUTH SETTINGS (manual check needed)
[Project-level items the user must verify in dashboard]

## AUDIT LOG COVERAGE
[Which events are logged / not logged]

## WHAT'S GOOD
[Positive controls in place]

## AUDIT COVERAGE
[Phases run / skipped]
```

---

## FIX KIT — write `AUTH-FIXES.md`

After the report, generate copy-paste-ready fix prompts (one per finding or per tight group), ordered CRITICAL → LOW. Same format as `/security-audit` Phase 14/15:

```
### FIX-N: [title]
**Severity:** ...
**Type:** code | sql-migration | config | external-action | supabase-mcp
**Complexity:** quick | medium | complex
**Files:** ...

**Prompt:**
> [Self-contained — a fresh Claude Code session can execute this without reading the rest of the kit. Include file paths, current code snippet, expected code snippet, verification.]

**Verification:** ...
```

Write the kit to `AUTH-FIXES.md` in project root. Add `AUTH-FIXES.md` to `.gitignore`. Include execution checklist table at the top. Include self-destruct note at the bottom (`rm AUTH-FIXES.md` after all items checked).

---

## OPTIONAL: APPLY FIXES IN-PLACE

If the user has explicitly approved auto-fix (e.g., `/auth-audit fix` argument or follow-up confirmation), iterate through the kit, apply each `code` / `sql-migration` / `config` fix, and check off the items in `AUTH-FIXES.md`. For `external-action` items, leave them in the file with clear manual steps. Do NOT push commits without confirmation.

Otherwise, stop after writing the kit and let the user drive.

START NOW. Use parallel agents for independent phases.
