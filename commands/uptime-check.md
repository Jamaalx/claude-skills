---
description: "Uptime & health check: endpoints, SSL certs, domains, Railway/Supabase/Cloudflare status, error rates, response times, alerting setup. Live infrastructure check."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*", "mcp__railway-mcp-server__*", "mcp__cloudflare__*"]
---

# UPTIME & HEALTH CHECK

You are performing a comprehensive uptime, health, and monitoring audit of the current project. Be thorough, systematic, and actionable. Every check must produce a concrete result — never skip a phase.

IMPORTANT: Use WebFetch for all live HTTP checks. Use the MCP tools for Railway, Supabase, and Cloudflare when available. Use WebSearch for external service status pages. Use Bash for local file analysis only.

---

## PHASE 0: IDENTIFY PROJECT ENDPOINTS

**Goal:** Build a complete inventory of every URL, endpoint, and external dependency this project touches.

1. Read `package.json` (or `pyproject.toml`, `requirements.txt`, `Cargo.toml`) to identify the project name and dependencies.
2. Search for environment files:
   - Glob for `**/.env*`, `**/*.env`, `**/env.*`, `**/.env.local`, `**/.env.production`
   - Read each one to extract URLs, API keys, service endpoints
3. Search for configuration files:
   - `next.config.*`, `nuxt.config.*`, `vite.config.*`, `wrangler.toml`, `vercel.json`, `railway.toml`, `Dockerfile`, `docker-compose.*`
   - Read each to find domains, ports, rewrites, redirects
4. Grep the codebase for URL patterns:
   - `https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` — all hardcoded URLs
   - `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_` — public env vars with URLs
   - `supabase`, `railway`, `cloudflare`, `vercel`, `netlify` — infrastructure references
   - `fetch(`, `axios.`, `got(`, `request(` — HTTP client calls to find API endpoints
5. Check for API route definitions:
   - Glob `**/api/**/*.{ts,js,py}`, `**/routes/**`, `**/endpoints/**`
   - List all API routes the project exposes
6. Check for webhook URLs:
   - Grep for `webhook`, `callback`, `hook` in code and config
7. Check for health check endpoints:
   - Grep for `/health`, `/healthz`, `/ready`, `/ping`, `/status`, `healthCheck`

Compile a master list:
```
PUBLIC ENDPOINTS:
- Main app: [url]
- API base: [url]/api
- Webhook endpoints: [urls]
- Health check: [url] (or MISSING)

INFRASTRUCTURE:
- Supabase: [project-ref].supabase.co
- Railway: [service].up.railway.app
- Cloudflare: [zone/domain]
- Other: [list]

EXTERNAL APIS:
- [service]: [url/domain]
```

---

## PHASE 1: ENDPOINT HEALTH CHECK

**Goal:** Test every discovered endpoint for availability, performance, and security basics.

For EACH public-facing URL discovered in Phase 0, use WebFetch to test:

1. **HTTP GET** the URL and record:
   - HTTP status code (200, 301, 404, 500, timeout)
   - Response time (note if WebFetch provides timing, otherwise note "responded" vs "timeout")
   - Whether the response body looks correct (HTML for pages, JSON for APIs)
   - Content-Length or approximate response size

2. **SSL check** — For each HTTPS URL:
   - Use WebFetch on `https://` and confirm it works
   - Use WebFetch on `http://` version and check if it redirects to HTTPS
   - Note any SSL errors in the response

3. **API endpoint testing** — For each API route:
   - Test with GET (and note if it returns 405 Method Not Allowed for POST-only routes)
   - Check if unauthenticated requests return proper 401/403 (not 500)
   - Check if non-existent routes return proper 404 (not 500)

4. **Security headers check** — Use WebFetch and look for:
   - `Strict-Transport-Security` (HSTS)
   - `X-Content-Type-Options: nosniff`
   - `X-Frame-Options` or `Content-Security-Policy` frame-ancestors
   - `X-XSS-Protection`
   - `Referrer-Policy`
   - `Permissions-Policy`

Record results in this format for each endpoint:
```
- URL: [url]
- Status: [200/301/404/500/timeout]
- Response time: [fast/slow/timeout]
- SSL valid: [yes/no/error details]
- HTTPS enforced: [yes/no]
- Security headers: [list present / list missing]
- Notes: [any issues]
```

---

## PHASE 2: DOMAIN & DNS CHECK

**Goal:** Verify domain health, DNS configuration, and registration status.

For each domain discovered:

1. **Domain registration** — Use WebSearch to check:
   - Search `"[domain] whois expiry"` or use a whois web service via WebFetch
   - WebFetch `https://who.is/whois/[domain]` or similar whois lookup service
   - Record: registrar, expiry date, auto-renew status if visible
   - FLAG if expiry is within 30 days

2. **DNS propagation** — Use WebFetch to check DNS via public API:
   - WebFetch `https://dns.google/resolve?name=[domain]&type=A` for A records
   - WebFetch `https://dns.google/resolve?name=[domain]&type=AAAA` for IPv6
   - WebFetch `https://dns.google/resolve?name=[domain]&type=CNAME` for CNAME
   - WebFetch `https://dns.google/resolve?name=[domain]&type=MX` for mail
   - WebFetch `https://dns.google/resolve?name=[domain]&type=TXT` for SPF/DKIM/DMARC
   - WebFetch `https://dns.google/resolve?name=[domain]&type=CAA` for CA authorization
   - WebFetch `https://dns.google/resolve?name=[domain]&type=NS` for nameservers

3. **DNS security** — Check:
   - DNSSEC enabled? (check `dns.google` response for `AD` flag)
   - CAA records present? (which CAs can issue certs)
   - SPF record exists and is valid?
   - DMARC record exists?

4. **Subdomain exposure** — Grep codebase for subdomains, check if any dev/staging subdomains are publicly accessible:
   - WebFetch `https://dev.[domain]`, `https://staging.[domain]`, `https://admin.[domain]`
   - FLAG any that respond (potential security risk)

Record:
```
DOMAIN: [domain]
- Registrar: [name]
- Expires: [date] [OK/WARNING/CRITICAL]
- Nameservers: [list]
- DNSSEC: [enabled/disabled]
- CAA records: [present/missing]
- A record: [IP]
- CNAME: [target]
- MX: [configured/missing]
- SPF: [valid/missing/invalid]
- DMARC: [valid/missing/invalid]
- Exposed subdomains: [list or none]
```

---

## PHASE 3: SSL CERTIFICATE AUDIT

**Goal:** Deep SSL/TLS security analysis for all domains.

For each domain, use WebFetch to check SSL Labs or similar:

1. **Certificate details** — WebFetch `https://crt.sh/?q=[domain]&output=json` (limited to recent):
   - Certificate issuer (Let's Encrypt, Cloudflare, DigiCert, etc.)
   - Validity period (not before / not after)
   - Subject Alternative Names (SANs) — what domains does the cert cover?
   - FLAG if expires within 14 days

2. **TLS configuration** — Use WebSearch for `"[domain] ssl test"` or check:
   - WebFetch the domain and note any TLS errors
   - Check if TLS 1.0/1.1 is disabled (these are deprecated)
   - Minimum should be TLS 1.2, prefer TLS 1.3

3. **HSTS check**:
   - WebFetch the domain and check response headers for `Strict-Transport-Security`
   - Check if `max-age` is at least 31536000 (1 year)
   - Check if `includeSubDomains` is set
   - Check if domain is in HSTS preload list: WebFetch `https://hstspreload.org/api/v2/status?domain=[domain]`

4. **Certificate Transparency**:
   - WebFetch `https://crt.sh/?q=%25.[domain]&output=json` to find ALL certificates ever issued
   - FLAG any unexpected certificates (could indicate compromise)
   - Check for wildcard certs (*.domain.com) — note security implications

5. **Mixed content risk**:
   - Grep codebase for `http://` URLs (non-HTTPS) that could cause mixed content warnings
   - FLAG any hardcoded HTTP URLs in frontend code

Record:
```
DOMAIN: [domain]
- Issuer: [CA name]
- Valid: [from] to [to] [OK/WARNING/CRITICAL]
- SANs: [list]
- TLS versions: [1.2, 1.3]
- HSTS: [yes/no, max-age, includeSubDomains, preloaded]
- CT logs: [normal/suspicious entries]
- Mixed content risks: [count or none]
```

---

## PHASE 4: RAILWAY HEALTH

**Goal:** Check Railway deployment health, stability, and configuration.

**IMPORTANT:** Only run this phase if Railway MCP tools are available. Test by calling `list-projects`. If it fails, skip this phase and note "Railway MCP not available."

If Railway is used by this project:

1. **Service inventory**:
   - Call `list-projects` to find the project
   - Call `list-services` for all services in the project
   - For each service, record: name, status, last deploy time

2. **Deployment health**:
   - Call `list-deployments` for each service
   - Check latest 5 deployments: any failures? How long do deploys take?
   - FLAG if the latest deployment failed
   - FLAG if there have been multiple failed deploys recently (instability)

3. **Logs analysis**:
   - Call `get-logs` for each service
   - Search logs for: `error`, `Error`, `ERROR`, `FATAL`, `OOM`, `killed`, `crash`, `SIGTERM`, `SIGKILL`
   - Search for crash loops: repeated restart patterns
   - Search for memory warnings: `heap`, `memory`, `allocation`
   - Count error frequency (errors per hour if timestamps available)

4. **Environment & configuration**:
   - Call `list-variables` to check environment configuration
   - FLAG any missing critical variables (DB URLs, API keys showing as empty)
   - FLAG any variables that look like they contain test/dev values in production
   - Check if `NODE_ENV=production` is set (for Node.js projects)

5. **Health check configuration**:
   - Check if Railway health check is configured (in railway.toml or service settings)
   - If the project has a `/health` endpoint, verify it's configured as the health check path
   - FLAG if no health check is configured (Railway won't know if the app is actually working)

6. **Domain & networking**:
   - Call `generate-domain` info or check service URLs
   - Verify custom domain is properly configured if applicable
   - Check if the service is publicly accessible

Record:
```
RAILWAY STATUS:
| Service | Status | Last Deploy | Deploy Status | Errors in Logs |
|---------|--------|-------------|---------------|----------------|

Health check configured: [yes/no]
Environment: [production/staging/unknown]
Recent failures: [count in last 24h]
Critical log entries: [list]
```

---

## PHASE 5: SUPABASE HEALTH

**Goal:** Check Supabase project health, database performance, and service availability.

**IMPORTANT:** Only run this phase if Supabase MCP tools are available. Test by calling `list-projects`. If it fails, skip this phase and note "Supabase MCP not available."

If Supabase is used by this project:

1. **Project status**:
   - Call `list-projects` to find the project
   - Call `get-project` for detailed status
   - Check: is the project active or paused?
   - FLAG if on free tier (auto-pause after 7 days of inactivity)
   - Record: region, plan tier, created date

2. **Database health**:
   - Call `execute_sql` with: `SELECT now() as server_time, version() as pg_version;`
   - Measure round-trip time (note when query was sent vs response)
   - Call `execute_sql` with: `SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';`
   - Call `execute_sql` with: `SELECT max_connections FROM pg_settings WHERE name = 'max_connections';`
   - FLAG if active connections > 80% of max
   - Call `execute_sql` with: `SELECT schemaname, relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 10;`
   - FLAG tables with high dead tuple counts (need vacuum)

3. **Slow queries**:
   - Call `execute_sql` with: `SELECT query, calls, mean_exec_time, max_exec_time, total_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;` (may not be available)
   - FLAG any queries with mean_exec_time > 1000ms

4. **Database size**:
   - Call `execute_sql` with: `SELECT pg_database_size(current_database()) as db_size_bytes, pg_size_pretty(pg_database_size(current_database())) as db_size;`
   - Call `list_tables` to see all tables
   - FLAG if approaching plan limits (500MB free, 8GB pro)

5. **Edge Functions**:
   - Call `list_edge_functions`
   - For each function, call `get_edge_function` to check status
   - Call `get_logs` with edge function filter to check for invocation errors
   - FLAG any functions with high error rates

6. **Auth service**:
   - Call `execute_sql` with: `SELECT count(*) as total_users FROM auth.users;`
   - Call `execute_sql` with: `SELECT count(*) as recent_signups FROM auth.users WHERE created_at > now() - interval '24 hours';`
   - Check auth configuration for security issues

7. **Storage**:
   - Call `execute_sql` with: `SELECT id, name, public FROM storage.buckets;`
   - FLAG any public buckets that might contain sensitive data

8. **Advisors**:
   - Call `get_advisors` to get Supabase's own recommendations
   - Record all advisor findings (performance, security, etc.)

9. **RLS (Row Level Security)**:
   - Call `execute_sql` with: `SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';`
   - FLAG any public tables without RLS enabled

Record:
```
SUPABASE STATUS:
- Project: [name] ([region])
- Status: [active/paused]
- Plan: [free/pro/team/enterprise]
- DB size: [size] / [limit]
- Active connections: [count] / [max]
- PostgreSQL version: [version]
- Edge functions: [count] ([healthy/errors])
- Tables without RLS: [count] [FLAG if any]
- Advisor findings: [count]
- Dead tuples needing vacuum: [count]
```

---

## PHASE 6: CLOUDFLARE HEALTH

**Goal:** Check Cloudflare zone health, SSL mode, security events, and performance.

**IMPORTANT:** Only run this phase if Cloudflare MCP tools are available. Test by calling `search` for the domain. If it fails, skip this phase and note "Cloudflare MCP not available."

If Cloudflare is used:

1. **Zone status**:
   - Call `search` or `execute` to check zone status
   - Verify zone is active
   - Check SSL mode (should be "Full (Strict)" for best security)
   - FLAG if SSL mode is "Flexible" (security risk — traffic to origin is unencrypted)

2. **Security events**:
   - Check for recent WAF blocks, challenges, or rate limiting triggers
   - Check for DDoS events
   - FLAG if there are unusual patterns (could indicate attack or misconfiguration)

3. **Analytics**:
   - Check for 4xx and 5xx error rates
   - FLAG if 5xx rate > 1% (server-side issues)
   - FLAG if 4xx rate > 10% (broken links, missing assets, or attacks)
   - Check bandwidth usage trends

4. **Workers**:
   - Check if any Cloudflare Workers are deployed
   - Verify worker health (no execution errors)
   - Check worker routes

5. **Page Rules / Redirect Rules**:
   - List active rules
   - Check for any rules that might cause issues (infinite redirects, etc.)

6. **DNS via Cloudflare**:
   - Check for proxied vs DNS-only records
   - FLAG any records that should be proxied but aren't (bypassing Cloudflare protection)
   - FLAG any records exposing the origin IP

Record:
```
CLOUDFLARE STATUS:
- Zone: [domain]
- Status: [active/pending/moved]
- SSL mode: [Full Strict/Full/Flexible/Off]
- Security events (24h): [count]
- Error rate (5xx): [percentage]
- Workers: [count] [healthy/errors]
- DNS records: [count proxied] / [count DNS-only]
```

---

## PHASE 7: EXTERNAL DEPENDENCIES

**Goal:** Check the status of all third-party services the project depends on.

1. **Identify dependencies** from Phase 0 endpoint discovery and package analysis.

2. **Check status pages** via WebSearch and WebFetch for each dependency:

   Common services to check (if used):
   - **OpenAI**: WebFetch `https://status.openai.com/api/v2/status.json`
   - **Stripe**: WebFetch `https://status.stripe.com/api/v2/status.json`
   - **Supabase**: WebFetch `https://status.supabase.com/api/v2/status.json`
   - **Railway**: WebSearch `"Railway status"` or `https://status.railway.app`
   - **Cloudflare**: WebFetch `https://www.cloudflarestatus.com/api/v2/status.json`
   - **Vercel**: WebFetch `https://www.vercel-status.com/api/v2/status.json`
   - **GitHub**: WebFetch `https://www.githubstatus.com/api/v2/status.json`
   - **Google APIs**: WebFetch `https://status.cloud.google.com/`
   - **Twilio/SendGrid**: WebFetch `https://status.twilio.com/api/v2/status.json`
   - **AWS**: WebSearch `"AWS status"` for relevant services

3. **Check fallback/graceful degradation**:
   - Grep codebase for try/catch around external API calls
   - Check if there are timeout configurations for external requests
   - Check if there are retry mechanisms (exponential backoff)
   - Check if there are circuit breakers
   - Check if there are fallback responses when external services are down
   - FLAG any external API calls without error handling

Record:
```
EXTERNAL DEPENDENCIES:
| Service | Status | Used For | Fallback? | Error Handling? |
|---------|--------|----------|-----------|-----------------|
```

---

## PHASE 8: MONITORING & ALERTING SETUP

**Goal:** Assess the current monitoring coverage and identify gaps.

Search the project for evidence of monitoring tools:

1. **Error tracking**:
   - Grep for: `sentry`, `@sentry/`, `LogRocket`, `logrocket`, `Bugsnag`, `bugsnag`, `Rollbar`, `rollbar`, `TrackJS`, `datadog`
   - Check package.json for monitoring dependencies
   - Check for DSN/API keys in env files
   - Verdict: [CONFIGURED / MISSING]

2. **Uptime monitoring**:
   - Grep for: `uptimerobot`, `pingdom`, `betteruptime`, `statuspage`, `freshping`
   - Check for any cron-based health checks in the code
   - Check for any external monitoring webhook endpoints
   - Verdict: [CONFIGURED / MISSING]

3. **Log aggregation**:
   - Grep for: `winston`, `pino`, `bunyan`, `morgan`, `loglevel`, `log4js`, structured logging
   - Check if logs are being sent to any external service
   - Check if logs have proper levels (error, warn, info, debug)
   - Verdict: [CONFIGURED / BASIC / MISSING]

4. **Performance monitoring**:
   - Grep for: `newrelic`, `New Relic`, `datadog`, `Datadog`, `elastic-apm`, `opentelemetry`
   - Check for Web Vitals tracking
   - Check for API response time tracking
   - Verdict: [CONFIGURED / MISSING]

5. **Alert channels**:
   - Grep for: `slack`, `discord`, `webhook`, `pagerduty`, `opsgenie`, `email.*alert`, `sms.*alert`
   - Check for notification configurations
   - Verdict: [CONFIGURED / MISSING]

6. **Status page**:
   - Check if the project has a public status page
   - Grep for: `statuspage`, `status.`, `cachet`, `instatus`
   - Verdict: [CONFIGURED / MISSING]

7. **Backup monitoring**:
   - Check if database backups are configured and monitored
   - Check if backup verification exists
   - Verdict: [CONFIGURED / MISSING]

Record:
```
MONITORING COVERAGE:
| Category | Status | Tool | Notes |
|----------|--------|------|-------|
| Error tracking | [YES/NO] | [tool] | [details] |
| Uptime monitoring | [YES/NO] | [tool] | [details] |
| Log aggregation | [YES/NO] | [tool] | [details] |
| Performance APM | [YES/NO] | [tool] | [details] |
| Alerting | [YES/NO] | [channels] | [details] |
| Status page | [YES/NO] | [tool] | [details] |
| Backup monitoring | [YES/NO] | [tool] | [details] |
```

---

## PHASE 9: AVAILABILITY RISKS

**Goal:** Identify single points of failure, scalability risks, and resilience gaps.

1. **Single points of failure**:
   - Is the app deployed to a single region? (Check Railway/Vercel/Cloudflare config)
   - Is there only one instance/replica? (No horizontal scaling)
   - Is there a single database with no read replicas?
   - Is there a single Redis/cache instance?
   - FLAG each SPOF found

2. **Auto-scaling**:
   - Check if the hosting platform supports auto-scaling
   - Check if it's configured
   - Check if there are resource limits set

3. **Database resilience**:
   - Connection pooling configured? (Check for PgBouncer, connection pool settings)
   - Connection limits appropriate? (Not too low, not unlimited)
   - Automatic failover configured?
   - Point-in-time recovery available?
   - Backup schedule?

4. **Rate limiting**:
   - Grep for rate limiting middleware
   - Check if rate limits are appropriate (not too aggressive for legitimate users)
   - Check if rate limiting is applied to public endpoints
   - FLAG if no rate limiting exists on public API endpoints

5. **Graceful shutdown**:
   - Grep for `SIGTERM`, `SIGINT`, `process.on`, `shutdown`, `graceful`
   - Check if the app handles shutdown signals properly
   - Check if in-flight requests are completed before shutdown
   - FLAG if no graceful shutdown handling exists

6. **Health check endpoint**:
   - Verify a health check endpoint exists in the codebase
   - Check what it tests (just "alive" vs DB connection vs full dependency check)
   - FLAG if no health check endpoint exists

7. **Caching**:
   - Check for caching strategies (Redis, in-memory, CDN)
   - Check cache invalidation logic
   - Check if critical paths have caching to survive backend slowdowns

8. **Dependency pinning**:
   - Check if package versions are pinned (lock files exist)
   - FLAG if no lock file exists (builds may break from dependency updates)

Record:
```
AVAILABILITY RISKS:
| Risk | Severity | Details | Mitigation |
|------|----------|---------|------------|
```

Severity levels: CRITICAL, HIGH, MEDIUM, LOW

---

## PHASE 10: GENERATE MONITORING SETUP & REPORT

**Goal:** Generate actionable recommendations and a monitoring setup guide.

### 10A: Create UPTIME-FIXES.md

If there are ANY issues found, create `UPTIME-FIXES.md` in the project root with:

```markdown
# Uptime & Health Fixes
# Generated: [today's date]
# AUTO-GENERATED FILE - Delete after implementing fixes

## Critical Issues (fix immediately)
[list with exact steps to fix]

## High Priority (fix within 1 week)
[list with exact steps to fix]

## Medium Priority (fix within 1 month)
[list with exact steps to fix]

## Low Priority (nice to have)
[list with exact steps to fix]

## Monitoring Setup Guide

### 1. Health Check Endpoint
[If missing, provide complete code for a /health endpoint appropriate to the framework]

### 2. Free Uptime Monitoring
[Step-by-step UptimeRobot or Better Uptime setup]

### 3. Error Tracking
[Step-by-step Sentry free tier setup]

### 4. Basic Alerting
[How to set up email/Discord alerts for downtime]

### 5. SSL Certificate Monitoring
[How to monitor cert expiry]

---
*This file should be deleted after implementing the fixes.*
*Add to .gitignore: UPTIME-FIXES.md*
```

### 10B: Add to .gitignore

Check if `.gitignore` exists and add `UPTIME-FIXES.md` to it (if not already present).

### 10C: Generate Final Report

Output the complete report in this exact format:

```
========================================
   UPTIME & HEALTH REPORT
   Project: [name from package.json]
   Date: [today's date]
   Status: [ALL GREEN / DEGRADED / DOWN]
========================================

## ENDPOINT STATUS
| Endpoint | Status | Response Time | SSL Expires | Notes |
|----------|--------|---------------|-------------|-------|
| [url] | [code] | [time] | [date] | [notes] |

## INFRASTRUCTURE STATUS
| Service | Status | Details |
|---------|--------|---------|
| Railway | [status] | [details] |
| Supabase | [status] | [details] |
| Cloudflare | [status] | [details] |

## DNS & DOMAIN STATUS
| Domain | Expires | DNSSEC | CAA | HSTS | Notes |
|--------|---------|--------|-----|------|-------|

## SSL CERTIFICATE STATUS
| Domain | Issuer | Expires | TLS | Grade | Notes |
|--------|--------|---------|-----|-------|-------|

## EXTERNAL DEPENDENCIES
| Service | Status | Fallback? | Error Handling? |
|---------|--------|-----------|-----------------|

## MONITORING COVERAGE
| Category | Status | Tool |
|----------|--------|------|

## AVAILABILITY RISKS
| Risk | Severity | Details |
|------|----------|---------|

## TOP RECOMMENDATIONS
1. [most critical fix]
2. [second most critical]
3. [third]
...

## FILES GENERATED
- UPTIME-FIXES.md (added to .gitignore) — detailed fix guide

========================================
   END OF REPORT
========================================
```

### IMPORTANT RULES:
- NEVER skip a phase. If a phase cannot be completed (e.g., no Railway MCP), explicitly note it as "SKIPPED: [reason]"
- ALWAYS test endpoints live — do not assume they work based on code alone
- ALWAYS check SSL certificates — expired certs are the #1 cause of preventable outages
- ALWAYS check domain expiry — expired domains can be hijacked
- Be specific in recommendations — "fix your SSL" is useless, "renew SSL cert for example.com before June 15" is actionable
- Record exact timestamps for all checks so the report can be compared over time
- If the project has NO monitoring at all, make that the #1 recommendation with full setup instructions
