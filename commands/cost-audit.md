---
description: "Cloud / infra cost (FinOps) audit: inventory billed services & current spend (Supabase, Railway, Hetzner, Cloudflare, Vercel, object storage, email/SMS, LLM providers), identify cost drivers & biggest line items, compute waste (oversized/always-on/idle instances, unused Supabase projects), database compute & egress, bandwidth without CDN, LLM token spend (model over-selection, no caching, no max-tokens, prompt bloat), storage & log/backup retention growth, redundant/duplicate services, free-tier/limit cliffs. Prioritizes savings by € impact vs effort. Read-only. Writes COST-FIXES.md. Complements architecture-review (cost SHAPE) with the live BILL."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*", "mcp__cloudflare__*"]
---

# CLOUD COST / FinOps AUDIT

You audit where money leaks across this project's infrastructure and produce a prioritized savings plan. The goal is **signal, not austerity** — find the spend that buys nothing (idle, oversized, duplicated, forgotten) and the spend that's about to spike, without recommending cuts that would hurt the product. `architecture-review` covers the cost *shape* at design time; this skill looks at the *actual bill* and the live resources.

**Read-only / advisory.** Inspect usage; never delete or downsize a live resource — every saving goes into the FIX KIT for the user to action deliberately (a wrong cut = an outage).

## INSTRUCTIONS
TaskCreate to track. Severity by **€/month wasted** (or risk of an imminent cost spike). Report + FIX KIT → `COST-FIXES.md`. Use MCP tools for live usage where available; otherwise ask the user for the current invoices/usage screens and reason from those.

---

## PHASE 1: BILLED-SERVICE INVENTORY & CURRENT SPEND
List every paying/metered service and its rough monthly cost:
- Supabase (per project — note there may be **several**), Railway, Hetzner (dedicated/VPS), Cloudflare, Vercel/Netlify.
- Object storage (S3/R2/GCS/Supabase Storage), CDN egress.
- Email/SMS (Resend/SendGrid/Twilio), push.
- **LLM/AI providers** (Anthropic/OpenAI/etc.) — often the fastest-growing line.
- Domains, monitoring, misc SaaS subscriptions.
Use MCP where possible: Supabase `get_cost`/`get_organization`/usage, Cloudflare analytics. Build a spend table ordered by cost.

---

## PHASE 2: COST DRIVERS — WHAT SCALES WITH USAGE
- For the top line items, what makes them grow (users, requests, storage, tokens, egress)?
- Identify the 1–3 items that dominate the bill — focus effort there (Pareto).
- Any line growing month-over-month that will become the dominant cost soon?

---

## PHASE 3: COMPUTE WASTE
- **Oversized instances**: CPU/RAM provisioned far above utilization (Railway service sizes, Hetzner spec vs load, Supabase compute add-on).
- **Always-on non-prod**: staging/dev/preview environments running 24/7 that could sleep or be on-demand.
- **Idle / zombie services**: deployed but unused, old experiments still running, duplicate deployments.
- **Serverless vs always-on mismatch**: paying for an always-on container for spiky/low traffic (or vice-versa — serverless cold-start cost for steady high traffic).

---

## PHASE 4: DATABASE & STORAGE
- **Unused / forgotten Supabase projects** (you may have many) — each can carry a floor cost; pause/consolidate candidates.
- Supabase compute tier vs actual load; egress charges; storage growth.
- **Storage bloat**: orphaned files in buckets, image originals kept alongside derivatives, old exports.
- **Log & backup retention**: over-long retention, oversized log ingestion, backup copies multiplying.
- DB growth from un-pruned tables (events, logs, soft-deletes) — cross-ref `db-health`.

---

## PHASE 5: BANDWIDTH / EGRESS
- Large assets served from the origin/container instead of a CDN (egress + compute) — cross-ref `perf-audit` 6g/CDN.
- Hot images/files not cached at the edge.
- Cross-region/cross-cloud data transfer that could be co-located.

---

## PHASE 6: LLM / AI TOKEN SPEND (often the sneakiest)
- **Model over-selection**: using a top-tier model where a cheaper/faster one would do for the task (classification, extraction, short replies). Right-size per call. (Consult the `claude-api` skill for current model tiers/pricing rather than guessing.)
- **No prompt caching** for repeated large system prompts / RAG context.
- **No `max_tokens` cap** / unbounded output; runaway agent loops (cross-ref `llm-security` cost-DoS).
- **Prompt bloat**: stuffing the whole KB into context every call instead of retrieving; redundant few-shots.
- **Retries** multiplying token cost; missing rate/cost caps per user.
- Embeddings recomputed instead of cached.

---

## PHASE 7: REDUNDANCY & SUBSCRIPTIONS
- Two services doing the same job (two error trackers, two analytics, overlapping monitoring).
- Paid SaaS seats/plans underused or forgotten.
- Free alternatives that fit (self-hosted on the box you already pay for — cross-ref `selfhost-updates`).

---

## PHASE 8: LIMIT / TIER CLIFFS
- Approaching a free-tier or plan limit that will jump the bill (rows, bandwidth, build minutes, MAU, function invocations)?
- Overage pricing exposure (a traffic spike or abuse → bill shock; tie rate-limiting in `api-security`/`resilience-audit`).
- Annual vs monthly plan savings on committed spend.

---

## OUTPUT — REPORT

```
========================================
   CLOUD COST / FinOps REPORT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Approx total/month, biggest drivers, total identified savings ~€X/mo]

## SPEND BREAKDOWN
| Service | ~€/mo | Driver | Trend | Notes |

## SAVINGS OPPORTUNITIES (by € impact)
### HIGH (>€X/mo) / MEDIUM / LOW
[each: the waste, estimated saving, the action, any risk/tradeoff]

## COST-SPIKE RISKS
[tier cliffs, overage exposure, fast-growing lines]

## DON'T-CUT  [spend that looks high but is earning its keep — avoid false economy]
## AUDIT COVERAGE  [what was from live MCP vs user-provided invoices]
```

Every opportunity has an estimated € saving, the action, and an explicit note if there's a tradeoff (don't recommend a cut that risks the product without saying so).

---

## FIX KIT — write `COST-FIXES.md`

All savings → `COST-FIXES.md` in the working dir, ordered by € impact. Each entry: the change (downsize / pause / consolidate / add CDN / switch model tier / add cache / set max-tokens / prune storage), estimated monthly saving, the exact steps (which dashboard / command), the **risk & how to verify nothing breaks** after, and a rollback note. Add an **Execution Checklist** table.

- **Safety banner**: "Verify utilization before downsizing; cut one thing at a time and watch for breakage. A wrong cut is an outage, not a saving."
- Add `COST-FIXES.md` to `.gitignore` (it details your infra & spend).
- End with a **Self-Destruct** note: delete once actioned.
- Recommend re-running quarterly (or after a launch/scale event).

START — inventory the bill first (Phase 1), then attack the dominant line items.
