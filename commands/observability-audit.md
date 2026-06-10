---
description: "Observability / instrumentation audit: structured logging quality, log levels & correlation IDs, secrets/PII in logs, error tracking (Sentry/Glitchtip — unhandled rejections, source maps, release tracking, noise), metrics (RED/USE, business KPIs), distributed tracing (OpenTelemetry across services/edge functions), alerting (routing, signal-vs-noise, actionable, on-call), dashboards & SLIs, security/audit event logging, and the practical test: 'could you debug a prod incident with what you have?' Writes OBSERVABILITY-FIXES.md. Internal instrumentation — complements uptime-check (external synthetic) and resilience-audit (failure handling)."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# OBSERVABILITY AUDIT

You audit whether this system can be **understood while it's running and debugged after it breaks**. The opposite of observability is "a user told us it's down and we have no idea why." Focus on *internal* instrumentation (logs, errors, metrics, traces, alerts) — `uptime-check` covers external synthetic monitoring, `resilience-audit` covers failure *handling*; here the question is **can you SEE what's happening?**

## INSTRUCTIONS
TaskCreate to track. Severity by **debuggability impact** (CRITICAL = a prod outage would be near-blind / errors silently swallowed → LOW = nice-to-have dashboard). Report + FIX KIT → `OBSERVABILITY-FIXES.md`.

---

## PHASE 1: LOGGING QUALITY
- **Structured vs string soup**: JSON logs with fields, or scattered `console.log("here", x)`? Structured logs are queryable; string logs are not.
- **Levels** used meaningfully (error/warn/info/debug), and production level set sensibly (not debug-spam, not error-only)?
- **Correlation / request / trace IDs** threaded through a request so you can follow one user's journey across functions/services?
- **Context**: do logs carry enough (user/tenant id, route, operation) to be actionable — without dumping **secrets or PII** (cross-ref `security-audit` / `gdpr-audit`)?
- **Swallowed errors**: `catch {}` or `catch (e) { /* nothing */ }` — failures that never get logged at all (the worst observability bug).
- **Retention & access**: where do logs go, how long kept, who can read, is it enough to investigate an incident from last week?

---

## PHASE 2: ERROR TRACKING
- Is there an error tracker (Sentry, Glitchtip, Bugsnag, Highlight)? Or do errors only exist as log lines nobody watches?
- **Unhandled** rejections / uncaught exceptions captured (server, client, edge functions, workers)?
- **Source maps** uploaded so stack traces are readable in prod (minified traces are useless)?
- **Release / version tagging** so you know which deploy introduced an error, and **regression detection** on new releases?
- **Grouping & noise**: are errors deduped into issues, or is it a firehose nobody triages? Alert fatigue = ignored alerts.
- Client-side errors captured too (the frontend fails silently otherwise)?

---

## PHASE 3: METRICS
- Any app/business metrics emitted (request rate, latency, error rate — RED; or saturation/utilization — USE)?
- Business KPIs instrumented (signups, orders, jobs processed, queue depth) — can you tell if the *product* is healthy, not just the servers?
- Where stored/visualized (Prometheus/Grafana, provider dashboards, none)?
- Cardinality sanity (not exploding labels), cost of the metrics stack.

---

## PHASE 4: TRACING
- For multi-service / serverless / edge-heavy systems: distributed tracing (OpenTelemetry) to follow a request across hops?
- Without it, can you tell *which* hop is slow/failing in a chain? If the architecture is a single monolith, note that tracing may be overkill (don't over-recommend — match the stage, like `architecture-review`).
- Slow-query / slow-endpoint visibility (cross-ref `db-health` / `perf-audit`).

---

## PHASE 5: ALERTING
- What alerts exist, and on what signals (error-rate spike, latency, queue/DLQ depth, disk, cert expiry, failed cron)?
- **Routing**: where do alerts go (Slack/Discord/PagerDuty/email), and does a human actually see them in time?
- **Signal vs noise**: are alerts actionable (each one means "do something") or ignorable? Flapping/duplicate alerts?
- **Coverage gaps**: the silent failures — a cron that stopped running, a DLQ filling up, a background worker that died — are these alerted? (cross-ref `resilience-audit` silent-failure watchlist).
- Is there an on-call / escalation path, or do alerts land in a channel nobody reads at night?

---

## PHASE 6: DASHBOARDS & SLIs
- A single place to see "is the system healthy right now"?
- Defined SLIs/SLOs (even informal: "p95 < 500ms", "error rate < 1%")?
- Provider-native observability used: Supabase logs/advisors (via MCP), Railway logs/metrics, Cloudflare analytics, Vercel observability — or left untouched?

---

## PHASE 7: SECURITY & AUDIT EVENT LOGGING
- Are security-relevant events logged (logins, failed auth, permission changes, admin actions, data exports)? Cross-ref `auth-audit`.
- Tamper-resistance / retention for audit logs (compliance, incident forensics)?
- Can you answer "who did what, when" after a security incident?

---

## PHASE 8: THE INCIDENT TEST
Run the thought experiment: **"It's 2am, error rate just spiked. With only what's instrumented today, how fast can you find the cause?"**
- Can you go from alert → affected users → failing component → root-cause log/trace?
- Where does the trail go cold? Each cold spot is a finding.

---

## OUTPUT — REPORT

```
========================================
   OBSERVABILITY AUDIT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Could you debug a 2am prod incident? Top 3 blind spots.]

## INSTRUMENTATION SCORECARD
| Pillar | Status | Notes |
| Logging | … |
| Error tracking | … |
| Metrics | … |
| Tracing | … |
| Alerting | … |
| Dashboards/SLI | … |
| Audit logging | … |

## FINDINGS BY DEBUGGABILITY IMPACT
### CRITICAL / HIGH / MEDIUM / LOW
[each: the blind spot, the incident it would prolong, the fix]

## SILENT-FAILURE BLIND SPOTS
## WHAT'S GOOD
## AUDIT COVERAGE
```

Every finding ties to a concrete "you wouldn't see X" consequence.

---

## FIX KIT — write `OBSERVABILITY-FIXES.md`

All fixes → `OBSERVABILITY-FIXES.md` in project root, CRITICAL → LOW. Each fix: what to instrument, the concrete change (add structured logger + request id / wire Sentry + source maps / add a DLQ-depth alert / add an audit-log table), type (`code | config | infra | external-action`), complexity, and verification (trigger the condition, confirm it shows up where expected). Add an **Execution Checklist** table.

- Add `OBSERVABILITY-FIXES.md` to `.gitignore` (create if missing).
- End with a **Self-Destruct** note: delete once applied.

START THE AUDIT NOW.
