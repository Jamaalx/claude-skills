---
description: "Test-suite audit: framework & runner detection, coverage measurement and gaps, CRITICAL-PATH coverage (payments / auth / data-integrity / webhooks), test quality (meaningful assertions, over-mocking, snapshot abuse, tests that can't fail), flaky tests (timing/order/network), unit-vs-integration-vs-E2E balance, error-path & edge-case coverage, CI gating. Prioritizes what to test FIRST by risk, not just coverage %. Writes TEST-FIXES.md. The safety net for fast-moving / AI-written code."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# TEST-SUITE AUDIT

You audit how well this project is *tested* — not to chase a coverage number, but to answer: **if a change broke something important, would a test catch it before users do?** Especially relevant when code is written fast (or by AI) and shipped often. The goal is risk-weighted: a tested checkout flow beats 90% coverage of getters.

## INSTRUCTIONS
TaskCreate to track. Severity by **risk of an undetected regression** (CRITICAL = untested money/auth/data path → LOW = cosmetic). Report + FIX KIT → `TEST-FIXES.md`.

---

## PHASE 1: TEST INVENTORY
- Detect framework(s) & runner: Jest, Vitest, Playwright, Cypress, pytest, Go test, etc. Config files, `test`/`spec` globs.
- Count tests and where they live; map test files → source areas they cover.
- Is there a coverage tool configured? Is coverage collected in CI?
- Test scripts in `package.json` / Makefile / CI — do they actually run?

---

## PHASE 2: COVERAGE — MEASURE & FIND THE GAPS
- Run coverage if feasible (`vitest run --coverage`, `jest --coverage`, `pytest --cov`) — capture line/branch %.
- **Coverage % is a weak signal alone.** Use it to find *zero-coverage* modules, not to celebrate a number.
- Map uncovered areas to their importance (Phase 3). A 40%-covered codebase where the 40% is the critical paths beats 85% of trivia.
- Flag files/dirs with 0% coverage that contain real logic.

---

## PHASE 3: CRITICAL-PATH COVERAGE (the part that matters most)
Identify the flows where a silent break = money lost, data corrupted, or security broken — then check each has tests:
- **Payments / billing**: checkout, subscription lifecycle, refunds, webhook handlers, idempotency (cross-ref `resilience-audit`).
- **Auth / authz**: login, session, password reset, role checks, RLS-protected mutations (cross-ref `auth-audit` / `rls-audit`).
- **Data integrity**: writes that must be atomic, money/quantity math, state machines (order status), migrations.
- **External integrations**: webhook signature verification, 3rd-party API failure handling.
- **The core domain action** of the product (the one feature that, if broken, the product is broken).
For each unprotected critical path → CRITICAL/HIGH finding with a "write this test first" entry.

---

## PHASE 4: TEST QUALITY (coverage ≠ correctness)
Read a sample of tests and look for:
- **Tests that can't fail**: no assertions, asserting `true === true`, asserting a mock was set up rather than behavior.
- **Over-mocking**: so much mocked that the test verifies the mocks, not the code. Especially mocking the very thing under test.
- **Snapshot abuse**: huge auto-updated snapshots nobody reviews (a diff that's always "just update it").
- **Tautological / implementation-coupled tests**: assert the implementation, break on every refactor, catch no bugs.
- **Happy-path only**: no error/empty/boundary cases.
- **Weak assertions**: `expect(result).toBeTruthy()` where a specific value matters.

---

## PHASE 5: FLAKY & NON-DETERMINISTIC TESTS
- Order-dependence (tests that pass alone, fail in suite, or vice-versa) — shared mutable state, no cleanup.
- Time/clock dependence (`Date.now()`, sleeps, real timers) instead of fake timers.
- Real network/DB/filesystem where it should be controlled/seeded.
- Race conditions in async tests (missing await, arbitrary `waitFor` timeouts).
- Randomness without a seed.
Flaky tests are worse than no tests — they train the team to ignore red. List them and the fix.

---

## PHASE 6: TEST-TYPE BALANCE
- Unit vs integration vs E2E mix (the "testing trophy"/pyramid). Common smells:
  - All-E2E, no integration → slow, brittle, flaky.
  - All-unit with heavy mocks → green suite, broken app (nothing tests the seams).
  - No integration tests around the DB/API boundary where most real bugs live.
- Are the slow/brittle E2E tests reserved for the few highest-value user journeys?

---

## PHASE 7: TEST DATA & ISOLATION
- Deterministic, seeded fixtures? Each test sets up and tears down its own state?
- No dependence on prod data / external services / a developer's local machine.
- DB tests run against an ephemeral/transactional DB, rolled back per test.
- Secrets/PII not hardcoded in fixtures.

---

## PHASE 8: CI GATING & SPEED
- Do tests run on every PR and **block merge** on failure (cross-ref `security-audit` for branch protection)?
- Is the suite fast enough that people actually run it locally (or so slow it's skipped)?
- Coverage threshold enforced, or just reported?
- Are flaky tests retried-to-green (hiding rot) vs quarantined+tracked?

---

## PHASE 9: MISSING TEST TYPES (gaps by category)
- API contract tests (request/response shape) for endpoints other services depend on.
- Migration tests (does the migration apply + roll back on a copy?) — cross-ref `migration-audit`.
- Accessibility assertions in component/E2E tests — cross-ref `a11y-audit`.
- Regression tests for past production bugs (is each fixed bug pinned by a test?).
- Type-level safety as a complement (strict TS, no `any` escape hatches on critical code).

---

## OUTPUT — REPORT

```
========================================
   TEST-SUITE AUDIT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Would a regression on a critical path be caught? Top 3 risks.]

## CRITICAL-PATH COVERAGE MATRIX
| Critical flow | Tested? | Type | Confidence | Gap |

## FINDINGS BY RISK
### CRITICAL / HIGH / MEDIUM / LOW
[each: what's untested or weak, the regression it would miss, the fix]

## FLAKY TESTS
## TEST-QUALITY SMELLS
## COVERAGE SNAPSHOT  [numbers, with the caveat that critical-path > %]
## WHAT'S GOOD
## AUDIT COVERAGE
```

Every finding names the concrete regression a missing/weak test would let through.

---

## FIX KIT — write `TEST-FIXES.md`

All fixes → `TEST-FIXES.md` in project root, ordered by **risk-first** (write critical-path tests before chasing coverage %). Each entry: what to test, a ready-to-adapt test skeleton (arrange/act/assert) in the project's framework, type (`new-test | fix-flaky | refactor-test | ci-config`), complexity, and how to confirm it actually fails when the code is broken (mutation check — break the code, see the test go red). Add an **Execution Checklist** table.

- Add `TEST-FIXES.md` to `.gitignore` (create if missing).
- End with a **Self-Destruct** note: delete once the tests are written.

START THE AUDIT NOW. Map critical paths first (Phase 3) — that's where the highest-value tests are.
