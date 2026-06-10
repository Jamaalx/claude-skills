---
description: "Email deliverability audit — why your mail lands in spam or bounces: SPF/DKIM/DMARC auth & alignment (deeper than attack-surface), DMARC policy enforcement + report analysis, sending infra (ESP setup, dedicated-vs-shared IP, transactional-vs-marketing domain separation), domain/IP reputation & blocklists (Spamhaus, Google Postmaster), content/spam-score (subject, HTML, plain-text part, link reputation, unsubscribe), list hygiene (bounce handling, suppression, no purchased lists, sunset policy), compliance (one-click unsubscribe, CAN-SPAM, GDPR consent), warmup & volume ramp, and rate monitoring (opens/bounces/complaints/feedback loops). Writes EMAIL-DELIVERABILITY-FIXES.md. Cross-refs attack-surface (DNS) and gdpr-audit (consent)."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# EMAIL DELIVERABILITY AUDIT

You audit whether this project's email actually reaches the inbox — transactional (password resets, receipts) and marketing (campaigns, newsletters). Deliverability is a mix of **authentication, reputation, content, list hygiene, and compliance**; a failure in any one sends you to spam or the bounce pile. `attack-surface` checks the DNS auth records for spoofing; this skill goes deeper into *getting delivered*.

## INSTRUCTIONS
Confirm the sending domain(s) and ESP with the user. TaskCreate to track. Severity by **deliverability impact** (CRITICAL = mail failing auth / on a blocklist / no unsubscribe → LOW = minor polish). Report + FIX KIT → `EMAIL-DELIVERABILITY-FIXES.md`.

---

## PHASE 1: AUTHENTICATION & ALIGNMENT
- **SPF** (`TXT v=spf1`): present, includes the real ESP(s), no `+all`, ≤10 DNS lookups, not multiple SPF records.
- **DKIM**: selector(s) published and valid for the ESP; key length ≥1024 (2048 preferred); signing actually enabled on sent mail.
- **DMARC** (`_dmarc` TXT): present; **policy** is `quarantine`/`reject` for real protection (a domain stuck on `p=none` forever is unprotected); `rua` (and optionally `ruf`) reporting addresses set; `pct` not silently low.
- **Alignment**: do the SPF/DKIM domains *align* with the From: domain (relaxed/strict)? DMARC passes only on alignment — a common silent failure.
- Resolve records live (`dig`/DoH) and verify against the actual ESP's required setup.

---

## PHASE 2: DMARC REPORT ANALYSIS
- If `rua` reports are being collected, summarize them: which sources send as your domain, pass/fail rates, any spoofing/unauthorized senders.
- Are legitimate senders (ESP, transactional service, support tooling) all authenticated, or is some real mail failing DMARC (and getting quarantined)?
- Recommend the safe path to tighten policy (`none` → `quarantine` → `reject`) based on what the reports show.

---

## PHASE 3: SENDING INFRASTRUCTURE
- ESP identified (Resend, SendGrid, Postmark, SES, Mailgun…) and configured correctly?
- **Dedicated vs shared IP** — appropriate for volume (shared is fine at low volume; dedicated needs warmup + steady volume).
- **Transactional vs marketing separation**: are they sent from **separate subdomains** (e.g. `mail.` for marketing, `notify.`/root for transactional)? Mixing lets a marketing reputation hit also sink password-reset emails — a serious reliability bug.
- Return-Path / bounce domain configured; custom tracking domain (not a shared ESP one with poor reputation).
- BIMI (optional) for brand logo + a trust signal (requires DMARC enforcement + often VMC).

---

## PHASE 4: REPUTATION & BLOCKLISTS
- Check the sending domain/IP against major blocklists (Spamhaus, etc. — via lookups/WebSearch).
- **Google Postmaster Tools** set up for domains sending to Gmail (the dominant inbox)? Domain reputation visible?
- Any history of spam traps / sudden volume spikes that tanked reputation?
- New domain with no sending history (cold) — flag the need for warmup (Phase 7).

---

## PHASE 5: CONTENT & SPAM-SCORE
- **Multipart**: emails include a plain-text part alongside HTML (HTML-only looks spammy)?
- Spam-trigger content: ALL-CAPS/excessive punctuation subjects, image-only emails, heavy image-to-text ratio, spammy phrases, URL shorteners, mismatched/low-reputation link domains.
- Valid, simple HTML (broken/bloated HTML hurts rendering + scoring); inlined CSS.
- One-click **unsubscribe link** present and working (also a compliance + Gmail/Yahoo requirement for bulk senders — `List-Unsubscribe` + `List-Unsubscribe-Post` headers).
- Sender name/From address recognizable and consistent.
- Run representative emails through a spam-score check (SpamAssassin-style) where possible.

---

## PHASE 6: LIST HYGIENE
- **Bounce handling**: hard bounces suppressed automatically (sending to dead addresses kills reputation)?
- **Suppression list** for unsubscribes/complaints honored across all sends?
- **No purchased/scraped lists** (instant reputation death + GDPR violation).
- **Engagement-based sending / sunset policy**: are long-inactive addresses pruned or down-ramped?
- Double opt-in for marketing (confirms valid, consenting addresses)?

---

## PHASE 7: WARMUP & VOLUME
- New domain/IP: gradual volume ramp rather than a cold blast (which gets throttled/spam-filed)?
- Consistent sending patterns (sudden spikes look like compromise/spam)?
- Volume within ESP/plan limits.

---

## PHASE 8: COMPLIANCE (overlaps `gdpr-audit` — coordinate, don't duplicate)
- **Consent**: marketing only to opted-in recipients; consent records kept (GDPR / RO). Transactional vs marketing distinction respected.
- **Unsubscribe**: easy, one-click, honored promptly; no "log in to unsubscribe" dark patterns.
- Physical postal address + clear sender identity in marketing mail (CAN-SPAM / many jurisdictions).
- Privacy policy linked; data-processing of email engagement disclosed.

---

## PHASE 9: MONITORING & FEEDBACK
- Are **bounce / complaint / open / delivery** rates tracked? (complaint rate >0.1% and bounce rate are the danger metrics for Gmail/Yahoo bulk rules).
- Feedback loops (FBLs) configured so complaints flow back to suppression?
- Alerting on a deliverability drop (cross-ref `observability-audit`)?

---

## OUTPUT — REPORT

```
========================================
   EMAIL DELIVERABILITY REPORT
   Sending domain(s): [list]   ESP: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY  [inbox-readiness + top 3 fixes]

## AUTHENTICATION
| Domain | SPF | DKIM | DMARC policy | Alignment | Verdict |

## FINDINGS BY DELIVERABILITY IMPACT
### CRITICAL / HIGH / MEDIUM / LOW
[each: what's wrong, why it sends mail to spam/bounce, the fix]

## REPUTATION & BLOCKLISTS
## CONTENT / COMPLIANCE
## LIST HYGIENE
## WHAT'S GOOD
## AUDIT COVERAGE
```

Every finding states how it costs you the inbox (auth fail → spam, dirty list → reputation drop, no unsubscribe → complaints + blocklist).

---

## FIX KIT — write `EMAIL-DELIVERABILITY-FIXES.md`

All fixes → `EMAIL-DELIVERABILITY-FIXES.md` in the working dir, CRITICAL → LOW. Each fix: the exact change — DNS record to add/edit (SPF/DKIM/DMARC, with the literal value), ESP setting, subdomain separation step, `List-Unsubscribe` header to add, suppression/bounce config, or content change — type (`dns | esp-config | code | content | process | external-action`), complexity, and verification (the `dig` / mail-tester / Postmaster check that should now pass). Add an **Execution Checklist** table.

- For DMARC tightening, give the **staged** plan (`none` → `quarantine pct=…` → `reject`) tied to report findings, never a blind jump to `reject`.
- Add `EMAIL-DELIVERABILITY-FIXES.md` to `.gitignore`.
- End with a **Self-Destruct** note: delete once applied.

START — confirm the sending domain(s) and ESP first, then resolve auth records live.
