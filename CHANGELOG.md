# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/) for its skill set: a new skill or a substantive scope change is a minor bump, wording / freshness fixes are a patch. Versions before 1.3.0 were reconstructed from git history; the repository does not carry git tags.

Monthly refreshes are made with the bundled [`/audit-update`](commands/audit-update.md) skill; structural fixes with [`/skills-doctor`](commands/skills-doctor.md).

## [1.3.1] - 2026-09-24

### Fixed
- `install.sh`: `--force` now overwrites in a single pass instead of first printing a "leaving as-is — re-run with --force" line for every locally edited skill; unknown arguments (e.g. the typo `-force`) are rejected instead of being silently ignored; `--help` added.

### Added
- `scripts/check-skills.sh` check 4 — sensitive data in `commands/` and `examples/`: credential-shaped strings, machine home paths, non-placeholder email addresses. `CONTRIBUTING.md` points to it.

### Notes
- Skill files unchanged: the 27 published skills are identical to the maintainer's local `~/.claude/commands/` as of this date.

## [1.3.0] - 2026-08-30

### Changed
- **audit-update 2026-08** refresh of three skills:
  - `email-deliverability`: new Phase 0 with the official bulk-sender thresholds (Google/Yahoo, Microsoft since April 2025, Apple aligned) — 5,000 msgs/day trigger, SPF+DKIM+DMARC all aligned, complaint rate below 0.30% (Google advises below 0.10%), one-click unsubscribe per RFC 8058 honoured within 2 days, transactional mail exempt.
  - `llm-security`: remapped to OWASP GenAI/LLM Top 10 **2026** (Hidden Context Exposure LLM08, Excessive Agency up to LLM03, Vector & Embedding Weaknesses LLM09, Improper Output Handling LLM10, Unbounded Consumption LLM06, Supply Chain LLM04 / Data & Model Poisoning LLM05); new Phase 8a on MCP servers as an attack surface — tool poisoning, rug pull, cross-server tool shadowing, context poisoning via tool output, over-privileged credentials.
  - `rls-audit`: `SECURITY DEFINER` query now reports grants, `anon_can_execute` and unpinned `search_path`, dangerous-first; new 5a tenant-from-payload pattern (secdef functions trusting a `p_tenant_id` argument) and RPC oracles that bypass app rate limits; new 5b policy performance — index on every policy-filtered column, `(select auth.uid())`, with a whole-word-regex / leading-index-column query that avoids false positives.
- README table rows for those three skills updated to match.

### Added
- `CHANGELOG.md` (this file) and a Changelog section in the README.
- CI: `.github/workflows/lint.yml` runs `scripts/check-skills.sh` on push and pull requests — frontmatter with a non-empty `description:`, every skill referenced in the README, README skill count matches `commands/`.
- `.github/dependabot.yml` (weekly, GitHub Actions), issue templates (bug report, skill request) and a pull request template matching `CONTRIBUTING.md`.
- README badges for the Lint workflow and the last audit-update, plus a maintenance note.

## [1.2.1] - 2026-06-10

### Fixed
- `/skills-doctor` pass: Railway phases in `security-audit`, `perf-audit`, `uptime-check` fall back to the `railway` CLI / dashboard when the MCP is not connected instead of silently skipping.
- `security-audit` Phase 4: OWASP Top 10:2025 category mapping and cross-refs to `/api-security`, `/llm-security`, `/deps-audit`, `/resilience-audit`.
- `seo-audit`: Next.js 15 → 16 (current stable); `skills-doctor` + `audit-update`: "WCAG 2.3" → "WCAG 3.0 (Working Draft)".
- README contract: auto-apply (`fix`) is for code-level audits; infra / advisory skills are read-only by design.

## [1.2.0] - 2026-06-10

### Added
- `architecture-review` — tradeoff-aware system-design review: system map, SPOFs, state location, scaling strategy, sync/async boundaries, monolith-vs-services, evolvability; outputs ADRs + staged roadmap.
- `resilience-audit` — failure modes: timeouts, retries + idempotency, dual-write / outbox, dead-letter queues, broker at-least-once, cron overlap, circuit breakers, graceful degradation and shutdown, backpressure.
- `selfhost-updates` — installed-vs-latest, CVE and EOL audit for the self-hosted platform stack (Coolify, self-hosted Supabase, Netdata, Postgres, Redis, proxies, n8n, Gitea, Grafana, MinIO, OS packages); backup-first update plan, read-only.
- `test-audit` — risk-first test-suite audit: critical-path coverage, test quality, flaky tests, unit / integration / E2E balance, CI gating.
- `observability-audit` — structured logging, secrets / PII in logs, error tracking, metrics, tracing, alert routing, dashboards / SLIs, audit logging.
- `cost-audit` — FinOps: billed-service inventory, compute waste, unused Supabase projects, egress without CDN, LLM token spend, storage growth, tier cliffs.
- `email-deliverability` — SPF / DKIM / DMARC alignment and policy, reputation and blocklists, spam-score, transactional-vs-marketing separation, list hygiene, one-click unsubscribe, warmup, bounce / complaint monitoring.
- Library now at **27 skills**.

### Changed
- `perf-audit`: application cache-aside correctness (invalidation, stampede, what not to cache) and large-file object-storage offload (signed URLs, metadata / blob split).
- `audit-update` research rotation and README table / cadence extended for the new skills.

## [1.1.0] - 2026-06-10

### Added
- `llm-security` — OWASP LLM Top 10: prompt injection (direct + indirect / RAG), RAG exfiltration, tool abuse, cost-DoS, red-team probe set.
- `api-security` — OWASP API Security Top 10: BOLA / IDOR, mass assignment, SSRF, shadow endpoints; REST + GraphQL + serverless.
- `server-hardening` — self-hosted Linux / Docker / Coolify hardening (SSH, firewall, ufw-bypassing Docker ports), read-only / guided.
- `attack-surface` — external recon on owned assets: DNS, subdomain takeover, TLS, headers, SPF / DKIM / DMARC.
- Library at 20 skills.

### Changed
- `security-audit` upgraded to 15 phases: AI / LLM agent security (Phase 14), deep supply-chain (Phase 15), OWASP 2025.
- `db-health`: table-prefix examples genericized (no project-specific names).

## [1.0.0] - 2026-06-04

### Added
- Initial release: 16 audit & maintenance skills — `a11y-audit`, `audit-update`, `auth-audit`, `backup-audit`, `db-health`, `dead-code`, `deps-audit`, `gdpr-audit`, `migration-audit`, `perf-audit`, `prod-readiness`, `rls-audit`, `security-audit`, `seo-audit`, `skills-doctor`, `uptime-check`.
- Installers (`install.sh`, `install.ps1`), sanitized example fix kits (`examples/`), `CONTRIBUTING.md`, MIT license.
