---
description: "Reliability / failure-mode audit — why distributed and async systems fall over: single points of failure, missing timeouts, retries without backoff/idempotency, the dual-write problem, missing dead-letter queues, broker/queue at-least-once semantics, cron-job overlap & missed runs, circuit breakers, graceful degradation, health checks & graceful shutdown, backpressure, outbox pattern. Focuses on how the system behaves when a dependency is slow or down. Writes RESILIENCE-FIXES.md. Complements uptime-check (monitoring) and backup-audit (recovery)."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# RESILIENCE / FAILURE-MODE AUDIT

You are a reliability engineer auditing how this system behaves **when things go wrong** — a dependency is slow, a queue redelivers, a cron overlaps, a third-party 500s, an instance dies mid-write. Most outages aren't "the code is wrong"; they're "the happy path was the only path." Find the missing failure handling and ship a fix kit.

**Scope boundaries (avoid overlap):**
- This skill = *failure handling inside the data/control flow* (timeouts, retries, idempotency, DLQ, outbox, degradation).
- `uptime-check` = monitoring/alerting/SSL (is it up?). `backup-audit` = data recovery (can we restore?). `security-audit` = DoS/abuse. `architecture-review` = the structural SPOFs. Cross-reference, don't duplicate.

## INSTRUCTIONS
TaskCreate to track. Parallel agents for independent subsystems. Severity by **outage risk** (CRITICAL = silent data loss / money double-spent / stuck queue; down to LOW). Report + FIX KIT → `RESILIENCE-FIXES.md`.

---

## PHASE 1: FAILURE-SURFACE INVENTORY
Map every place the system depends on something that can be slow or fail:
- External HTTP/API calls (payment, email/SMS, maps, LLM providers, scrapers).
- Database & cache calls.
- Queue/broker producers and consumers.
- Cron / scheduled jobs and background workers.
- Inter-service calls.
- File/object-storage operations.
For each, note: sync or async? what happens to the user / the data if it hangs or errors right now?

---

## PHASE 2: TIMEOUTS (the #1 missing primitive)
- Does **every** outbound call have an explicit timeout? (DB query, HTTP client, LLM call, queue op). A call with no timeout = a thread/connection held forever = cascading hang under load.
- Are timeouts *sane* (a 30s upstream behind a 10s gateway = guaranteed 504s)?
- Total request budget: do nested calls sum to less than the caller's timeout?
- LLM/streaming calls especially — these are slow and variable; unbounded = bill + hang.

---

## PHASE 3: RETRIES & IDEMPOTENCY (where most data corruption hides)
- Are retries present on transient failures — **with exponential backoff + jitter** (not tight loops that hammer a struggling dependency = retry storm)?
- Retry budget / max attempts bounded?
- **Idempotency**: is every *retried* or *redelivered* operation safe to run twice? A retried "charge card" / "send email" / "create order" without an **idempotency key** = double charge, duplicate email, duplicate row.
  - Payment/checkout flows: idempotency keys passed to the provider?
  - Webhook handlers: deduped by event id? (providers redeliver)
  - Queue consumers: idempotent, since brokers are at-least-once?
- Are non-idempotent writes protected (unique constraints, upserts, dedup tables) so a double-execution is caught by the DB?

---

## PHASE 4: QUEUES / BROKERS / EVENT FLOW
- Delivery semantics understood and handled? (at-least-once is the norm → consumers MUST be idempotent — see Phase 3).
- **Dead-letter queue**: do messages that fail N times go to a DLQ, or are they dropped/infinitely retried? Is the DLQ **alerted on** (Slack/Discord/email), or a silent graveyard?
- Consumer acks: ack *after* successful processing (not before — else crash = lost message)?
- Poison messages: one bad message can't block the whole partition/queue?
- Ordering assumptions: does the code assume in-order delivery the broker doesn't guarantee?
- Backlog handling: what happens if consumers fall behind — does the queue grow unbounded?

---

## PHASE 5: CRON / SCHEDULED JOBS (quietly fragile)
- **Overlap**: can a job start before the previous run finished (long run + short interval)? Is there a lock / single-flight guard?
- **Missed runs**: if the host was down at trigger time, is the run lost forever, or caught up? Idempotent + catch-up logic?
- **Partial failure**: a job processing 1000 items — does item #500 failing abort the rest, or is each item independent + retryable? Is progress checkpointed?
- Visibility: does anyone find out when a scheduled job *fails or silently stops running*? (a cron that dies quietly is a classic invisible outage)
- Timezone/DST correctness on schedules.

---

## PHASE 6: DUAL-WRITE & CONSISTENCY UNDER PARTIAL FAILURE
- Any operation that writes to the DB **and** does a second side-effect (publish event, call service, charge, send)? If the first succeeds and the second fails, is the system left inconsistent?
- Is the **outbox pattern** (or transactional event publish) used where it matters, or is it a naive `await db.commit(); await broker.publish()` with a gap in between?
- Compensating actions / sagas for multi-step distributed operations — present where needed, absent where over-engineered?
- "Exactly-once" assumptions that don't hold in reality?

---

## PHASE 7: ISOLATION — CIRCUIT BREAKERS, BULKHEADS, DEGRADATION
- **Circuit breaker** on flaky/slow external deps so a dying dependency doesn't take down the caller (and gets a chance to recover)?
- **Bulkheads**: is one slow dependency able to exhaust the shared connection/thread pool and starve everything else?
- **Graceful degradation**: when a non-critical dependency is down, does the app degrade (serve stale cache, hide a widget, queue for later) or hard-fail the whole request? The recommendations service being down shouldn't blank the page.
- Fallbacks/defaults for non-critical reads.

---

## PHASE 8: LIFECYCLE — HEALTH CHECKS & GRACEFUL SHUTDOWN
- **Liveness vs readiness** distinguished? (readiness should fail while warming up / when a critical dep is down, so the LB stops routing).
- **Graceful shutdown**: on deploy/scale-down (SIGTERM), does the instance drain in-flight requests and finish/return queue messages, or drop them mid-flight?
- Connection-pool sizing vs DB max connections (a scale-out event shouldn't exhaust Postgres connections — relevant for serverless + Supabase; consider a pooler).
- Startup ordering: does the app crash-loop if a dependency isn't ready yet, or retry-with-backoff to connect?

---

## PHASE 9: BACKPRESSURE & OVERLOAD
- Under a traffic spike, does the system shed load gracefully (429 / queue / reject) or fall over (OOM, connection exhaustion, cascading timeouts)?
- Rate limiting to protect *downstream* deps (not just for abuse — cross-ref `api-security` for the abuse angle)?
- Bounded queues / concurrency limits on workers?

---

## PHASE 10: FAILURE OBSERVABILITY (can you even see it fail?)
- Are errors *surfaced* (alerting on error-rate spikes, DLQ depth, retry exhaustion, cron failure) — or swallowed (`catch {}` with no log, failures only visible if a user complains)?
- Correlation/trace ids to follow a failed request across services?
- Are timeouts/retries/breaker trips emitted as metrics?
- Cross-ref `uptime-check` for the external/synthetic-monitoring side; here focus on *internal* failure signals.

---

## OUTPUT — REPORT

```
========================================
   RESILIENCE / FAILURE-MODE REPORT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[How does this system behave when a dependency degrades? Top 3 outage risks.]

## FAILURE-SURFACE MAP
| Dependency | Sync/Async | Timeout? | Retry+idempotent? | Fallback? | On failure today → |

## FINDINGS BY OUTAGE RISK
### CRITICAL / HIGH / MEDIUM / LOW
[each: location (file:line), the failure scenario ("if X is slow/down, then…"), the data/UX consequence, the fix]

## SILENT-FAILURE WATCHLIST
[places where a failure would currently go unnoticed — no DLQ alert, swallowed catch, cron with no monitoring]

## WHAT'S GOOD
## AUDIT COVERAGE
```

Every finding states the concrete failure scenario and consequence, not just "missing retry".

---

## FIX KIT — write `RESILIENCE-FIXES.md`

All fixes → `RESILIENCE-FIXES.md` in project root, CRITICAL → LOW. Each fix: the failure it prevents, before/after code (add timeout / wrap with backoff+idempotency key / add DLQ + alert / add outbox / add readiness probe), type (`code | config | infra | external-action`), complexity, and a verification (ideally a way to *inject* the failure and confirm graceful behavior — e.g. "kill the worker mid-batch and confirm no item is lost or double-processed"). Add an **Execution Checklist** table.

- Add `RESILIENCE-FIXES.md` to `.gitignore` (create if missing).
- End with a **Self-Destruct** note: delete once applied.

START THE AUDIT NOW.
