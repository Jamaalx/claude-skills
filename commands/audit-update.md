---
description: "Update all audit skills (security, llm-security, api-security, server-hardening, attack-surface, architecture-review, resilience-audit, selfhost-updates, test, observability, cost, email-deliverability, auth, rls, deps, db-health, seo, perf, a11y, gdpr, uptime) with latest web research, best practices, and framework changes. Run monthly. For structural skill issues (broken MCP refs, overlaps), use /skills-doctor instead."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, Write, Edit]
---

# AUDIT SKILLS UPDATER

You are updating all Claude Code audit skills to reflect the latest web standards, framework updates, and best practices. This should be run monthly or when major framework updates are released.

This skill REFRESHES audit-skill content (checks, thresholds, references). For structural problems (renamed MCP tools, redundant skills, gaps in coverage), use `/skills-doctor`.

## STEP 1: RESEARCH LATEST CHANGES

Search the web for the latest updates in these areas (use WebSearch for each):

### Security
- "OWASP Top 10 2026 changes"
- "Next.js security advisories [current year]"
- "Supabase security best practices [current year]"
- "npm supply chain attacks [current year]"
- "new web security headers [current year]"

### AI / LLM security (llm-security.md)
- "OWASP Top 10 for LLM Applications [current year] update"
- "prompt injection mitigation [current year]"
- "AI agent / tool-use security best practices [current year]"
- "RAG data exfiltration / multi-tenant vector store security"
- "MCP server security risks [current year]"

### API security (api-security.md)
- "OWASP API Security Top 10 [current/next edition]"
- "GraphQL security best practices [current year]"
- "BOLA / mass assignment prevention [current year]"

### Server / container hardening (server-hardening.md)
- "Docker security best practices [current year]"
- "Coolify security hardening [current year]"
- "CIS benchmark Ubuntu / Debian [current year]"
- "fail2ban / sshd hardening [current year]"

### External attack surface (attack-surface.md)
- "subdomain takeover [current year]"
- "DMARC / BIMI adoption [current year]"
- "certificate transparency recon"

### Architecture & resilience (architecture-review.md, resilience-audit.md)
- "software architecture best practices [current year]"
- "modular monolith vs microservices [current year]"
- "idempotency / outbox pattern / dual-write problem"
- "dead letter queue + retry best practices [current year]"
- "graceful degradation / circuit breaker patterns"
- "serverless cold start / connection pooling Supabase [current year]"

### Self-hosted stack (selfhost-updates.md)
- "Coolify latest release [current year]"
- "Supabase self-hosting recommended versions [current year]"
- "PostgreSQL / Redis / Ubuntu end-of-life dates" (verify endoflife.date still the source)
- "Netdata / Traefik / n8n / Grafana latest stable + CVEs [current year]"

### Testing (test-audit.md)
- "testing trophy vs pyramid [current year]"
- "Vitest / Playwright / pytest latest best practices"
- "flaky test detection [current year]"

### Observability (observability-audit.md)
- "OpenTelemetry adoption [current year]"
- "Sentry / structured logging best practices [current year]"
- "SLO / alerting on-call best practices"

### Cost / FinOps (cost-audit.md)
- "Supabase / Railway / Cloudflare / Vercel pricing changes [current year]"
- "LLM token pricing [current year]" (re-check model tiers via the claude-api skill)
- "cloud cost optimization FinOps [current year]"

### Email deliverability (email-deliverability.md)
- "Gmail / Yahoo bulk sender requirements [current year]"
- "DMARC enforcement / BIMI [current year]"
- "one-click unsubscribe List-Unsubscribe-Post [current year]"

### SEO
- "Google algorithm updates [current year]"
- "Core Web Vitals changes [current year]"
- "Google Search Console new features [current year]"
- "Next.js SEO changes [current year]"
- "structured data Google updates [current year]"
- "Google AI overview SEO impact [current year]"

### Performance
- "Core Web Vitals thresholds [current year]"
- "Next.js [latest version] performance features"
- "React [latest version] performance improvements"
- "new web performance APIs [current year]"
- "Lighthouse [latest version] scoring changes"

### Uptime/Infrastructure
- "Railway new features [current year]"
- "Supabase new features [current year]"
- "Cloudflare new security features [current year]"
- "best uptime monitoring tools [current year]"

### Auth & Identity
- "Supabase Auth / GoTrue breaking changes [current year]"
- "@supabase/ssr cookie pattern updates"
- "passkey / WebAuthn adoption [current year]"
- "OWASP authentication cheat sheet"

### RLS / Database
- "Supabase RLS best practices [current year]"
- "Postgres 17 / 18 RLS changes"
- "supabase_realtime RLS"

### Dependencies / Supply chain
- "npm supply-chain attacks [current year]"
- "pip-audit vs safety latest"
- "knip / depcheck updates"

### Accessibility
- "WCAG 3.0 working draft status" / "WCAG 2.2 still current standard"
- "European Accessibility Act enforcement [current year]"
- "axe-core latest rules"

### GDPR / RO
- "ANSPDCP cookie guidance update [current year]"
- "EDPB guidelines [current year]"
- "Legea 506/2004 updates"

## STEP 2: READ CURRENT SKILLS

Read all audit skill files:
- ~/.claude/commands/security-audit.md
- ~/.claude/commands/llm-security.md
- ~/.claude/commands/api-security.md
- ~/.claude/commands/server-hardening.md
- ~/.claude/commands/attack-surface.md
- ~/.claude/commands/architecture-review.md
- ~/.claude/commands/resilience-audit.md
- ~/.claude/commands/selfhost-updates.md
- ~/.claude/commands/test-audit.md
- ~/.claude/commands/observability-audit.md
- ~/.claude/commands/cost-audit.md
- ~/.claude/commands/email-deliverability.md
- ~/.claude/commands/auth-audit.md
- ~/.claude/commands/rls-audit.md
- ~/.claude/commands/deps-audit.md
- ~/.claude/commands/db-health.md
- ~/.claude/commands/seo-audit.md
- ~/.claude/commands/perf-audit.md
- ~/.claude/commands/uptime-check.md
- ~/.claude/commands/a11y-audit.md
- ~/.claude/commands/gdpr-audit.md
- ~/.claude/commands/backup-audit.md
- ~/.claude/commands/migration-audit.md
- ~/.claude/commands/dead-code.md
- ~/.claude/commands/prod-readiness.md

If any file does not exist, note it and skip it in subsequent steps.

## STEP 3: IDENTIFY GAPS

For each skill, compare the current content with the latest research from Step 1:
- Are there new OWASP categories not covered?
- Are there new Google ranking factors not checked?
- Are there new Core Web Vitals metrics or changed thresholds?
- Are there new framework features that improve security/performance?
- Are there deprecated checks that should be removed?
- Are there new tools/packages that should be recommended?

## STEP 4: UPDATE SKILLS

For each gap found, update the relevant skill file:
- Add new phases or sub-checks
- Update thresholds and metrics
- Remove outdated checks
- Add references to new tools/packages
- Update version numbers and framework-specific advice

## STEP 5: CHANGELOG

After all updates, output a summary:
```
AUDIT SKILLS UPDATE - [date]
=============================

## security-audit.md
- [changes made]

## seo-audit.md
- [changes made]

## perf-audit.md
- [changes made]

## uptime-check.md
- [changes made]

## Sources
- [URLs of key sources used]
```
