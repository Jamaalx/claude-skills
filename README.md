# claude-skills

16 production-grade audit & maintenance slash-commands for [Claude Code](https://claude.com/claude-code). Each runs a deep, multi-phase audit on your project and writes a copy-paste-ready fix kit so the work can be applied by a fresh Claude Code session — including by you, an agent, or a different model.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-7c3aed)](https://claude.com/claude-code)

> Battle-tested on real Next.js + Supabase + Railway + Hetzner stacks. Each skill produces an executable plan, not just a list of complaints.

## What's in the box

| Skill | What it does | Cadence |
|-------|--------------|---------|
| [`/security-audit`](commands/security-audit.md) | Full security audit: code, dependencies, secrets, OWASP, originality, live infra (Supabase / Railway / Cloudflare / GitHub), data privacy. 13 phases. | Monthly |
| [`/auth-audit`](commands/auth-audit.md) | Auth & session: login flow, cookies, JWT handling, middleware safety, privilege escalation, MFA, rate-limiting, audit logging. | Monthly |
| [`/rls-audit`](commands/rls-audit.md) | Supabase RLS / Postgres authorization: unprotected tables, permissive policies, self-elevation vectors, `SECURITY DEFINER`, service-role leakage. | Monthly |
| [`/deps-audit`](commands/deps-audit.md) | CVEs per locked version, outdated packages, breaking changes on majors, supply-chain risk, license compliance, bundle bloat. npm + pip. | Monthly |
| [`/db-health`](commands/db-health.md) | Postgres / Supabase: missing & unused indexes, slow queries (`pg_stat_statements`), bloat, FK orphans, N+1 patterns, growth. | Quarterly |
| [`/perf-audit`](commands/perf-audit.md) | Bundle size, Core Web Vitals, images, fonts, caching, SSR/SSG, DB queries, API response times, Lighthouse. | Quarterly |
| [`/seo-audit`](commands/seo-audit.md) | Meta tags, OpenGraph, structured data, sitemap, robots.txt, headings, internal linking, mobile, Core Web Vitals. | Quarterly |
| [`/uptime-check`](commands/uptime-check.md) | Endpoints, SSL certs, domains, Railway / Supabase / Cloudflare status, error rates, response times, alerting setup. | Quarterly |
| [`/a11y-audit`](commands/a11y-audit.md) | WCAG 2.2 AA conformance: keyboard nav, screen reader, contrast, alt text, ARIA, focus, forms, motion, mobile. Runs axe-core + Lighthouse. | Quarterly |
| [`/gdpr-audit`](commands/gdpr-audit.md) | GDPR / ePrivacy: cookie banner, privacy policy, terms, data retention, user rights, sub-processor DPA, marketing consent. RO-specific extras (ANSPDCP, ANPC). | Quarterly |
| [`/backup-audit`](commands/backup-audit.md) | DR posture: Supabase PITR, Coolify/Hetzner snapshots, retention, restore-test recency, GitHub mirroring, Cloudflare config backup. | Quarterly |
| [`/migration-audit`](commands/migration-audit.md) | Safety review of pending Postgres migrations: destructive ops, locking impact on large tables, reversibility, RLS preservation. | On demand (before applying) |
| [`/dead-code`](commands/dead-code.md) | Unused files, exports, components, npm/pip packages, duplicate logic, commented-out blocks, orphan API routes, dangling assets. | Quarterly |
| [`/prod-readiness`](commands/prod-readiness.md) | Fast pre-deploy gate (<2 min): RLS on new tables, env vars, build & typecheck, no PII in logs, service-role not in client. | Before every prod deploy |
| [`/audit-update`](commands/audit-update.md) | Refreshes every audit skill above with the latest web research, framework versions, OWASP/WCAG editions, best practices. | Monthly |
| [`/skills-doctor`](commands/skills-doctor.md) | Meta-audit: scans all skills for broken MCP tool refs, stale framework versions, overlapping scope, missing coverage. | Quarterly |

## Design principles

Every audit skill follows the same contract:

1. **Multi-phase deep scan** — typically 10-15 phases, parallel agents where independent.
2. **Severity-tagged findings** — CRITICAL / HIGH / MEDIUM / LOW / INFO, with file:line / SQL / config locations.
3. **Self-contained fix kit** — writes `<DOMAIN>-FIXES.md` to the project root with one copy-paste prompt per finding. A fresh Claude Code session can execute any prompt without context.
4. **Auto-gitignored** — fix kits contain attack details, never commit. Skills add `*-FIXES.md` to `.gitignore`.
5. **Optional auto-apply** — pass `fix` as argument (`/auth-audit fix`) to apply remediations in place. Stops on first failure; never pushes commits without confirmation.
6. **Self-destruct** — kits end with `rm <kit>.md` instruction once items are checked off.

## Install

### macOS / Linux

```bash
git clone https://github.com/Jamaalx/claude-skills.git
cd claude-skills
./install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/Jamaalx/claude-skills.git
cd claude-skills
.\install.ps1
```

### Manual

Copy any skill file into your Claude Code commands directory:

- **Unix / macOS:** `~/.claude/commands/`
- **Windows:** `%USERPROFILE%\.claude\commands\`

Files are loaded automatically by Claude Code. Verify with `/help` (or just start typing `/auth-audit`).

## Required tools

Most skills work with stock Claude Code. A few use optional MCP servers for live infrastructure checks:

| MCP server | Used by | Required? |
|------------|---------|-----------|
| Supabase MCP (cloud or self-hosted via Postgres MCP) | `rls-audit`, `db-health`, `migration-audit`, `backup-audit`, `security-audit` | Strongly recommended |
| Cloudflare MCP | `security-audit`, `backup-audit`, `uptime-check` | Optional |
| Playwright MCP | `a11y-audit`, `perf-audit` | Optional |
| `gh` CLI | `security-audit`, `backup-audit` | Recommended |

Each skill degrades gracefully — if an MCP server isn't connected, the corresponding phase is skipped and noted in the report.

## Examples

See [`examples/`](examples/) for sanitized sample fix-kit outputs from fictional projects.

## Cadence — when to run what

```
Daily / per deploy   → /prod-readiness
Monthly             → /security-audit, /auth-audit, /rls-audit, /deps-audit, /audit-update
Quarterly           → /db-health, /perf-audit, /seo-audit, /uptime-check, /a11y-audit,
                       /gdpr-audit, /backup-audit, /dead-code, /skills-doctor
On demand           → /migration-audit (before applying), /perf-audit (after major refactor)
```

## Compatibility

Built for **Claude Code** (CLI / desktop / IDE extensions / web). Skills are plain Markdown with frontmatter — they also work in:

- Cursor (paste into a custom command)
- Other Claude API harnesses (the prompt body is the instruction)

The fix-kit format is portable: any agent / model that follows the embedded prompts can execute the remediation.

## Contributing

Pull requests welcome. To add a new skill:

1. Drop a `commands/your-skill.md` file with frontmatter:
   ```yaml
   ---
   description: "One-line scope — used by Claude to decide when to invoke."
   allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, ...]
   ---
   ```
2. Follow the multi-phase + fix-kit pattern (see [`auth-audit.md`](commands/auth-audit.md) as a reference).
3. Document the cadence in the README table.
4. Run `/skills-doctor` to verify structural consistency.

## License

[MIT](LICENSE). Use it, fork it, ship it.

## Author

Built by [Alex Mantello](https://github.com/Jamaalx). Stress-tested across multiple HoReCa / SaaS / B2B2C stacks running Next.js + Supabase + Railway + Hetzner + Cloudflare.

If a skill saved your weekend, a star is enough thanks.
