# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/) for its skill set: a new skill or a substantive scope change is a minor bump, wording / freshness fixes are a patch. Versions before 1.3.0 were reconstructed from git history; the repository does not carry git tags.

Monthly refreshes are made with the bundled [`/audit-update`](commands/audit-update.md) skill; structural fixes with [`/skills-doctor`](commands/skills-doctor.md).

## [1.4.0] - 2026-11-01

### Changed
- **audit-update 2026-11** refresh of 25 skills (architecture-review and resilience-audit: no change needed):
  - `security-audit`: Phase 14 renumbered to OWASP GenAI/LLM Top 10 **2026** + Agentic Top 10 (ASI); A07 mapped to `/auth-audit`; Next.js / RSC RCE advisories (CVE-2025-55182); `sb_secret_` keys in the secret scan; Phase 15 npm changes (classic tokens revoked 2025-12-09, 90-day write tokens, `min-release-age`), 2025-26 worm campaigns, worms persisting via agent/IDE config, provenance is not authorization.
  - `llm-security`: intro now maps to the 2026 edition (was still "2025") and to the OWASP Top 10 for Agentic Applications; persistent-memory poisoning check (ASI06); MCP spec 2026-07-28 authorization checks for servers the project exposes (RFC 8707 audience, RFC 9728 metadata, no token passthrough, Client ID Metadata Documents).
  - `api-security`: 2023 edition confirmed current; new check for API6 Sensitive Business Flows; Next.js Server Functions treated as endpoints, `proxy.ts` is not an authz boundary; 2026 Next.js SSRF CVEs.
  - `auth-audit`: Next.js `proxy.ts` (ex-`middleware.ts`) + proxy-bypass CVEs; Server Actions `Origin: null` CSRF bypass (CVE-2026-27978); Supabase `getClaims()`, new API keys and asymmetric JWT signing keys; NIST SP 800-63B-4 password rules; passkeys at AAL2/AAL3.
  - `server-hardening`: OpenSSH 10.x (DSA removed, ML-KEM hybrid key exchange default); Ubuntu 26.04 defaults (sudo-rs, chrony NTS); Docker 29 nftables backend; Coolify advisories.
  - `attack-surface`: cert expiry judged against shrinking lifetimes (CA/B Forum SC-081, Let's Encrypt 45-day plan); OCSP stapling no longer a finding; LE client-auth EKU end; DMARC per RFC 9989 (`t=` replaces `pct`, `np=`).
  - `selfhost-updates`: self-hosted Supabase versioned releases, Envoy gateway, PG17 default; Coolify v4 stable; PostgreSQL 13/14 EOL dates; MinIO community edition archived; Redis 8 AGPLv3 option / Valkey.
  - `backup-audit`: Supabase backup/PITR facts corrected per plan (Free has none; PITR add-on needs Small compute); Railway volume backups; restore test via "Restore to a New Project" and its caveats.
  - `uptime-check`: cert-lifetime-based expiry thresholds, no more Let's Encrypt expiry emails; Stripe and Railway status endpoints fixed.
  - `perf-audit`: Next.js 16.x (no First Load JS in build output → `next analyze`, Turbopack default, Cache Components, `proxy.ts`, `preload` replaces `priority`, `revalidateTag` signature); React 19.2/19.3; Node 18/20 EOL; Lighthouse 13; Tailwind v4; Cloudflare Auto Minify / Mirage retired.
  - `seo-audit`: FAQ (2026-05-07), HowTo, sitelinks search box and June 2025 rich results removed from expectations; pagination guidance; new 9f on AI Overviews / AI Mode controls; `preload` in Next.js 16.
  - `a11y-audit`: EN 301 549 V4.1.1 (WCAG 2.2 baseline); WCAG 3.0 still a Working Draft; axe tags fixed to include WCAG 2.1; WCAG 2.2-only criteria checks; `@axe-core/playwright`, `@axe-core/react` dropped for React 18+, `next lint` removed.
  - `deps-audit`: `uv.lock` / `bun.lock`, `uv audit`, OSV-Scanner v2; Shai-Hulud; install-script and release-cooldown hardening (npm 12 `allowScripts`, pnpm 11 `allowBuilds` / `minimumReleaseAge`, uv `exclude-newer`); npm trusted publishing; depcheck (archived) → knip / deptry.
  - `dead-code`: Knip v6 commands; `unimported` / `depcheck` dropped (archived), `deptry` for Python; Tailwind v4 `@source`.
  - `test-audit`: Vitest 4 removed `coverage.all` (use `coverage.include`); Vitest / Playwright flaky-test options.
  - `prod-readiness`: `sb_secret_` and legacy `service_role` in bundle; explicit GRANTs since Supabase stopped exposing new tables by default (all projects from 2026-10-30); migration list / dry-run; advisors gate.
  - `migration-audit`: lock table corrected (CONCURRENTLY = SHARE UPDATE EXCLUSIVE, rewrite vs metadata-only, FK locks, `lock_timeout`); PG18 `NOT NULL ... NOT VALID`; GRANT requirement; advisors after apply.
  - `rls-audit`: default-privileges change with a `pg_default_acl` query; both Supabase key generations and asymmetric signing keys; advisor lint ids.
  - `db-health`: stats-reset / replica caveats for "unused" indexes; PG18 skip scan, `EXPLAIN` BUFFERS default, vacuum timing columns, `uuidv7()`; advisor lints.
  - `observability-audit`: Sentry JS v10 notes (OTel v2, INP, `enableLogs`, `sendDefaultPii`); OTel semconv maturity (HTTP stable, GenAI moved out and still Development, profiles Alpha).
  - `cost-audit`: Vercel Active CPU applies only after redeploy; Anthropic prompt-caching and Batch API multipliers; regional-inference premium.
  - `email-deliverability`: Microsoft enforcement date 2025-05-05; Gmail rejections since Nov 2025; DMARC is RFC 9989; BIMI needs enforcement + VMC/CMC; Postmaster Tools v2 compliance dashboard.
  - `gdpr-audit`: EU ODR link removed (platform closed 2025-07-20); guest-checkout note (EDPB Recs 2/2025); new Phase 9 regulatory status — Digital Omnibus (not law), AI Act Art. 50 + Omnibus delays (Reg. 2026/1744), Data Act switching, EDPB CEF 2026.
  - `audit-update` / `skills-doctor`: research queries updated (current OWASP editions, Agentic Top 10, MCP authorization, cert lifetimes, npm token/cooldown changes, RFC 9989).
- README: last audit-update badge and maintenance note → 2026-11.

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
