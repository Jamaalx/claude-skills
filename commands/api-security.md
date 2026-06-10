---
description: "API security audit (OWASP API Security Top 10 2023): BOLA/IDOR, broken authentication, broken object-property-level authz (mass assignment + excessive data exposure), unrestricted resource consumption / rate limiting, broken function-level authz, SSRF, security misconfiguration, improper inventory (shadow/zombie endpoints), unsafe consumption of 3rd-party APIs. Tests REST + GraphQL + serverless/edge routes. Generates API-SECURITY-FIXES.md."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# API SECURITY AUDIT (OWASP API Top 10)

You are an API penetration tester auditing this project's API surface. Web-app OWASP ≠ API OWASP — APIs fail differently (object-level authz, mass assignment, resource exhaustion). Map every finding to the **OWASP API Security Top 10 (2023)**. Covers REST, GraphQL, tRPC, Next.js route handlers, Supabase edge functions, and any serverless endpoints.

This is the deep companion to `security-audit` Phase 11. Run it for API-heavy projects (REST/GraphQL backends, headless services, BFFs, any project where the API is the product).

## INSTRUCTIONS
Run all phases, TaskCreate to track, parallel agents for independent reads. Report with severity (CRITICAL/HIGH/MEDIUM/LOW/INFO), then a FIX KIT → `API-SECURITY-FIXES.md`.

---

## PHASE 1: ENDPOINT INVENTORY (API9 — Improper Inventory)

1. Enumerate EVERY endpoint: REST routes, GraphQL resolvers, tRPC procedures, Next.js `app/api/**/route.ts` + `pages/api/**`, Supabase edge functions, webhooks, server actions.
2. For each: method, path, auth required?, authz checked?, input schema?, output shape, rate-limited?
3. **Shadow / zombie endpoints**: old `/v1` still live next to `/v2`? Debug/test/admin routes? Internal endpoints reachable externally? Undocumented routes?
4. Is there an OpenAPI/GraphQL schema, and does it match reality (no more, no less)?

---

## PHASE 2: BROKEN OBJECT-LEVEL AUTHZ — BOLA/IDOR (API1, #1 risk)

The most common and most severe API flaw.
- For every endpoint that takes an object id (`/orders/:id`, `?userId=`, `/documents/{uuid}`): is **ownership/tenant** verified server-side, or does it trust the id from the request?
- Can user A fetch/modify/delete user B's resource by changing the id? (sequential ints make it trivial; UUIDs only obscure, don't protect)
- Supabase: is this enforced by **RLS** or only by app code? (app-code-only = bypassed via the data API). Cross-check with `rls-audit`.
- Nested/relational access: `/orgs/:org/projects/:proj` — is BOTH levels checked?

---

## PHASE 3: BROKEN AUTHENTICATION (API2)

- Unauthenticated endpoints that should require auth.
- JWT: signature verified? `alg:none` / algorithm-confusion accepted? expiry enforced? secret strength? tokens in URLs/logs?
- Credential stuffing / brute force: rate limit + lockout on login, password-reset, OTP, token endpoints?
- API keys: how issued, rotated, scoped, revoked? Long-lived keys in clients?
- Session/refresh-token handling, logout invalidation.

---

## PHASE 4: BROKEN OBJECT-PROPERTY-LEVEL AUTHZ (API3)

### 4a. Excessive Data Exposure
- Do responses return whole DB objects and rely on the client to hide fields? (password hashes, internal flags, other users' data, tokens, `is_admin`, soft-deleted rows)
- GraphQL over-fetching; `SELECT *` serialized straight to JSON.

### 4b. Mass Assignment
- Does the endpoint bind request body straight into a model/update? (`{...req.body}`, `Object.assign(entity, body)`, Prisma `data: body`)
- Can a client set fields they shouldn't — `role`, `isAdmin`, `balance`, `verified`, `userId`, `price`? → privilege escalation / tampering.
- Are writes allowlisted to explicit fields (Zod `.pick`, DTO) rather than blocklisted?

---

## PHASE 5: UNRESTRICTED RESOURCE CONSUMPTION (API4)

- Rate limiting present and per-identity (per-user/key/IP), not just global?
- Pagination bounded? (`limit=999999`, `first: 100000`, no cap = memory/DB blowup)
- GraphQL: query depth/complexity limits, batching/aliasing abuse, introspection disabled in prod?
- File uploads: size + count + type limits?
- Expensive ops (export, report, search, fan-out) gated/queued?
- Cost-amplification: endpoints that trigger paid 3rd-party calls (SMS, email, LLM) without caps?

---

## PHASE 6: BROKEN FUNCTION-LEVEL AUTHZ (API5)

- Admin/privileged actions reachable by normal users? (guessable `/admin/*`, hidden methods, `DELETE` on a route that only checks auth not role)
- Is role/permission checked per-action server-side, or assumed from UI hiding the button?
- Different HTTP methods on the same route with inconsistent authz?

---

## PHASE 7: SSRF (API7) & INJECTION

- **SSRF**: any endpoint that fetches a user-supplied URL (webhooks, image proxy, link preview, import-from-URL, PDF render)? Can it hit `169.254.169.254` (cloud metadata), internal IPs, `localhost`, `file://`? Allowlist enforced?
- Injection: SQL/NoSQL/command/LDAP from API params; ORM raw queries; Supabase `.rpc()`/`.filter()` with raw user strings.
- Header injection, CRLF, host-header trust.

---

## PHASE 8: SECURITY MISCONFIGURATION (API8)

- CORS: `Access-Control-Allow-Origin: *` with credentials? Reflective origin echo?
- Security headers on API responses (HSTS, X-Content-Type-Options; CSP for any HTML).
- Verbose errors: stack traces, SQL errors, framework banners, internal IPs in responses.
- Default creds, sample endpoints, GraphQL playground/introspection in prod.
- TLS enforced; no sensitive data over HTTP.
- HTTP methods: is `TRACE`/`OPTIONS` leaking; are unused methods rejected?

---

## PHASE 9: UNSAFE CONSUMPTION OF 3RD-PARTY APIs (API10)

- Does the app blindly trust data returned by upstream APIs (no validation before use/store)?
- Redirects followed to arbitrary hosts; upstream errors leaked to clients.
- Webhook **inbound** verification: Stripe/GitHub/provider signatures validated? Replay protection (timestamp + idempotency)? Secrets compared in constant time?
- Timeouts + retries bounded on outbound calls.

---

## PHASE 10: LIVE PROBE (optional, authorized assets only)

Only against the user's OWN staging/production with permission, read-only and non-destructive:
- `curl -sI` each public endpoint → inspect headers, CORS, server banner.
- Hit a protected endpoint without a token → expect 401, not 200/500-with-data.
- Swap an object id between two test users → expect 403/404, not the other user's data.
- If Supabase MCP is available, cross-check that the data API respects RLS for the anon role.

Never test third-party APIs or assets you don't own.

---

## OUTPUT — REPORT

```
========================================
   API SECURITY REPORT (OWASP API Top 10)
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY  [overall risk]

## ENDPOINT INVENTORY
| Method | Path | Auth | Authz(object) | Rate-limit | Schema | Notes |

## FINDINGS BY SEVERITY
### CRITICAL / HIGH / MEDIUM / LOW / INFO
[each: API-Top-10 id (API1..API10), endpoint, file:line, attack scenario, fix]

## BOLA/IDOR MATRIX
[endpoint | takes id? | ownership checked? | RLS-backed?]

## SHADOW / ZOMBIE ENDPOINTS
## WHAT'S GOOD
## AUDIT COVERAGE
```

Every finding: endpoint + file:line, OWASP-API id, attack scenario, severity, specific fix (code or config).

---

## FIX KIT — write `API-SECURITY-FIXES.md`

All fixes → `API-SECURITY-FIXES.md` in project root, CRITICAL → LOW. Each fix: self-contained copy-paste prompt with file paths, before/after code (or Supabase SQL/RLS migration for authz fixes), type (`code | sql-migration | config | external-action`), complexity, verification (e.g. the exact `curl` that should now return 403). Add an **Execution Checklist** table at the top.

- Add `API-SECURITY-FIXES.md` to `.gitignore` (create if missing).
- End with a **Self-Destruct** note: delete after all fixes applied — it documents live attack vectors.

START THE AUDIT NOW.
