---
description: "Self-hosted / open-source stack update audit. Inventories the platform software you run (Coolify, self-hosted Supabase stack, Netdata, Postgres, Redis, Traefik/Caddy/Nginx, n8n, Gitea, Grafana/Prometheus, MinIO, Docker images, OS packages...), resolves installed vs latest-stable versions, flags security releases & CVEs, EOL/end-of-life (via endoflife.date), and breaking changes between versions. Produces a prioritized, backup-first update plan with changelog links + rollback notes. Read-only/advisory — never auto-updates. Writes SELFHOST-UPDATES.md. Complements deps-audit (app libraries) and server-hardening (config)."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*"]
---

# SELF-HOSTED STACK UPDATE AUDIT

You audit the **open-source / self-hosted platform software** running on the user's own infra (a dedicated server / VPS, e.g. Hetzner + Coolify + Docker) and answer one question per component: *is it out of date, and does it NEED updating (security / EOL) or merely COULD it?* Then ship a prioritized, backup-first update plan.

**Scope boundary (no overlap):**
- This skill = *platform/service software you self-host* (Coolify, Supabase stack, Netdata, Postgres engine, Redis, proxies, dashboards, the OS) — versions, security releases, EOL, upgrade path.
- `deps-audit` = application libraries (npm/pip). `server-hardening` = config/exposure. `uptime-check` = is it running. Cross-reference, don't duplicate.

**Operating rules:**
- **Read-only / advisory.** Inventory and recommend; do NOT run upgrades. Updating Coolify / Postgres major / the OS is high-risk and must be the user's deliberate action.
- Two modes (like `server-hardening`): **Remote** (if SSH/MCP access is authorized, run inspection live) or **Guided** (default — emit the exact inspection commands for the user to run via `! <cmd>` or paste back, then analyze).

## INSTRUCTIONS
TaskCreate to track. Parallel agents for independent components. Severity by **update urgency** (CRITICAL = actively-exploited CVE / past EOL → down to LOW = cosmetic). Report + FIX KIT → `SELFHOST-UPDATES.md`.

---

## PHASE 1: INVENTORY THE STACK
Discover what's actually running (live if authorized, else hand the user the commands):
- **Containers**: `docker ps --format '{{.Image}}\t{{.Names}}\t{{.Status}}'` and `docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}'` — the primary source of truth on a Coolify/Docker box.
- **Compose / Coolify**: parse `docker-compose*.yml`, Coolify-managed stack definitions, `.env` for pinned versions/tags.
- **OS & packages**: `cat /etc/os-release`, `uname -r`, `apt list --installed 2>/dev/null` (or `dpkg -l`), key daemons.
- **System services**: `systemctl list-units --type=service --state=running`.
- **Language runtimes**: node/python/go versions if hosting apps directly.

Build a component table: **name | how it's run (container/apt/binary) | image/tag or version string | role**.

Common components to expect & name explicitly: **Coolify**, **self-hosted Supabase** (postgres, gotrue/auth, postgrest, realtime, storage-api, kong, studio, supavisor/pooler, vector, imgproxy), **Netdata**, **PostgreSQL** engine, **Redis/Valkey**, **Traefik / Caddy / Nginx**, **n8n**, **Gitea**, **Grafana / Prometheus**, **MinIO**, **MySQL/MariaDB**, **RabbitMQ**, message brokers.

---

## PHASE 2: RESOLVE INSTALLED VERSIONS (pin down the real number)
For each component, get the precise installed version — a tag like `:latest` is NOT a version:
- Container with a real tag (`postgres:15.6`) → that's the version.
- Container on `:latest` / a moving tag → resolve the actual build: `docker image inspect <id>` for labels, or the app's own version endpoint (Coolify settings, Netdata `/api/v1/info`, `SELECT version()` in Postgres, `redis-server --version`, `traefik version`, `node -v`).
- **Flag `:latest`/unpinned tags themselves as a finding** — you can't reason about drift or roll back what you can't name (ties to `deps-audit` supply-chain + reproducibility).

---

## PHASE 3: LATEST STABLE & "IS THERE AN UPDATE?"
For each component, find the current latest-stable release (WebSearch / WebFetch authoritative sources):
- GitHub Releases API: `https://api.github.com/repos/<org>/<repo>/releases/latest` (Coolify=`coollabsio/coolify`, Netdata=`netdata/netdata`, n8n=`n8n-io/n8n`, Gitea, Grafana, etc.).
- Docker Hub / GHCR tags for image-based components.
- Supabase self-hosted: check the official self-hosting release notes / `supabase/supabase` for the recommended stack versions (the stack moves together — don't bump one service blindly).
- Compute the gap: same / patch behind / minor behind / **major behind**.

---

## PHASE 4: SECURITY RELEASES & CVEs (the part that makes it URGENT)
- For each installed version, search for known CVEs / security advisories: GitHub Security Advisories, vendor security pages, NVD. WebSearch `"<component> <version> CVE"` and `"<component> security release [current year]"`.
- Distinguish "a newer version exists" from "the installed version is **vulnerable**" — only the latter is urgent.
- Special attention: anything **internet-exposed** (proxy, Coolify dashboard, Netdata if public, Studio) with a known CVE = escalate severity (cross-ref `server-hardening` / `attack-surface` for exposure).
- Supply-chain: was any image pulled from an unofficial source? (cross-ref `deps-audit`).

---

## PHASE 5: END-OF-LIFE (EOL)
Running past-EOL software = no more security patches = latent CRITICAL.
- Use **endoflife.date** (great canonical source): `https://endoflife.date/api/<product>.json` (e.g. `postgresql`, `redis`, `ubuntu`, `debian`, `nodejs`, `nginx`, `traefik`, `grafana`). Compare installed major against supported/EOL dates.
- Flag: already-EOL (CRITICAL), EOL within ~6 months (HIGH — plan now), supported (OK).
- Postgres major version EOL is the classic one — a major upgrade is a project, not a `docker pull`; plan it early.

---

## PHASE 6: BREAKING CHANGES & UPGRADE PATH
For each recommended update, read the release notes / changelog between installed → target:
- Breaking changes, required migration steps, config-format changes, removed features.
- **Multi-step upgrades**: some tools won't jump N majors at once (Postgres needs `pg_upgrade`/dump-restore; some apps require stepping through intermediate majors). Note the required path.
- Supabase self-hosted: the services are version-matched — identify the coordinated target set, not à-la-carte bumps.
- Coolify: has its own self-update flow; note current vs target and whether a DB/schema migration runs.
- Data-bearing upgrades (Postgres, Redis with persistence, MinIO) → **backup first** (cross-ref `backup-audit`); for Postgres schema/major steps also cross-ref `migration-audit`.

---

## PHASE 7: UPDATE METHOD & ORDER
For each component, the concrete update mechanism:
- Coolify-managed service → bump tag in Coolify + redeploy (or Coolify self-update for Coolify itself).
- Raw Docker → `docker pull <pinned-new-tag>` + recreate (prefer pinning to a specific version, not `:latest`).
- `apt` package / OS → `apt update && apt upgrade` (+ reboot if kernel); unattended-upgrades for security (cross-ref `server-hardening`).
- Recommend a **safe order**: security-critical & EOL first; data-bearing components with backup taken first; proxy/edge last (so you don't cut access mid-update); test on staging if one exists.

---

## OUTPUT — REPORT

```
========================================
   SELF-HOSTED STACK UPDATE REPORT
   Host: [hostname]   Date: [today]
========================================

## EXECUTIVE SUMMARY  [overall freshness + how many security-urgent / EOL]

## STACK INVENTORY & DRIFT
| Component | Run via | Installed | Latest stable | Gap | EOL? | CVE? | Urgency |

## UPDATE NEEDED — URGENT (security / EOL)
[component | issue | target version | why now]

## UPDATE RECOMMENDED (behind, no urgency)
## UP TO DATE  [the green ones — reassure, don't churn]
## UNPINNED / :latest  [can't reason about — pin these]

## WHAT'S GOOD
## AUDIT COVERAGE  [live vs guided; anything unresolved]
```

Every component: installed vs latest, whether the gap is **security/EOL-urgent** or just-behind, and the upgrade path with caveats. Be explicit when something is *fine as-is* — the goal is signal, not "update everything."

---

## FIX KIT — write `SELFHOST-UPDATES.md`

All updates → `SELFHOST-UPDATES.md` (in the working dir / infra repo), ordered URGENT → recommended. Each entry: component, installed→target, **the exact update command(s)**, a link to the changelog/security advisory, breaking-change notes, a **backup-first** step for data-bearing services, and a **rollback** note (previous pinned tag / snapshot to restore). Add an **Execution Checklist** table.

- **Safety banner**: "Take a backup/snapshot before data-bearing or major upgrades. Update one component at a time and verify health before the next. Don't bulk-`:latest`." Cross-ref `backup-audit` (snapshot) and `migration-audit` (Postgres).
- Add `SELFHOST-UPDATES.md` to `.gitignore` (it maps which versions/CVEs your infra is exposed to).
- End with a **Self-Destruct** note: delete once the plan is executed.
- Recommend re-running monthly — self-hosted stacks drift silently and security releases land without notice.

START — inventory first (Phase 1) in guided mode unless live access is authorized.
