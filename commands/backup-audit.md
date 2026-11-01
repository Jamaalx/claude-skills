---
description: "Backup & disaster-recovery audit: Supabase PITR + daily backup status, Coolify/Hetzner snapshots, retention, restore-test recency, GitHub repo backup, Cloudflare config backup. Generates BACKUP-FIXES.md with restore-test playbook."
allowed-tools: [Bash, Read, Glob, Grep, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, "mcp__claude_ai_SupaBase__*", "mcp__cloudflare__*"]
---

# BACKUP & DR AUDIT

You are an SRE auditing backup posture. Goal: confirm that if production dies tonight, every critical system can be restored to within an acceptable RPO/RTO. Output a report + `BACKUP-FIXES.md` with action items.

---

## PHASE 1: INVENTORY

Identify every system holding state that would hurt to lose:

- Supabase projects (DB + storage + auth)
- Railway services (any volumes / persistent state) — check each volume's Backups tab: daily (kept 6 days) / weekly (27 days) / monthly (89 days) schedules; backups are deleted if the volume is wiped and restore only within the same project + environment, so keep an off-platform dump too (source: https://docs.railway.com/reference/backups)
- Hetzner servers (filesystems, Docker volumes, Coolify state)
- GitHub repositories
- Cloudflare config (DNS, Workers, R2)
- Local-only files referenced from memory (e.g., a personal credentials/secrets vault on disk — if it's not backed up, it's a single point of failure)
- External SaaS: Google Workspace data, etc.

For each, declare desired RPO (max acceptable data loss) and RTO (max acceptable downtime).

---

## PHASE 2: SUPABASE

Via MCP:
- For each project: tier, daily backup status, PITR enabled?, retention window.
- `list_projects` → for each, confirm `status = 'ACTIVE_HEALTHY'`.
- Migrations history committed to git? (`supabase/migrations/`)
- Edge functions: source in git? (deployed = backed up via redeploy capability)
- Storage buckets: are uploads also stored elsewhere or only here?

Note Supabase tier limits (source: https://supabase.com/docs/guides/platform/backups):
- Free: no managed backups to rely on and no PITR — export regularly yourself (`supabase db dump`) to off-site storage. Treat a Free project with no dump job as **no backup**.
- Pro: 7 days of daily backups. Team: 14 days. Enterprise: up to 30 days.
- PITR: paid add-on on Pro/Team/Enterprise, needs at least the Small compute add-on, 7/14/28-day retention; once enabled, daily backups stop (PITR replaces them).
- **Storage objects are NOT in database backups** on any plan — bucket files need their own copy (S3 sync/rclone to off-site).
- Deleting a project deletes its backups irreversibly; a restore makes the project unavailable while it runs.

For each project, the verdict: can you restore to T-1h? T-24h? T-7d?

---

## PHASE 3: HETZNER / COOLIFY

If accessible:
- Coolify backup schedule for each app's volume.
- Hetzner storage box / external backup destination configured?
- Snapshot frequency for the server itself (Hetzner offers snapshots).
- Test: can you restore a single DB / volume from the most recent backup?

If not accessible via tooling, write a checklist for the user to verify manually.

---

## PHASE 4: GITHUB

```
gh repo list --limit 100
```

For each critical repo:
- Default branch protection on?
- At least one collaborator besides owner?
- Mirror on a second remote (Gitea on Hetzner, Codeberg, GitLab)?
- Releases / tags for known-good versions?

Local git working copies are also backups — confirm critical repos exist on at least one machine besides the dev workstation.

---

## PHASE 5: CLOUDFLARE

If MCP available:
- DNS records: any export of the zone file? (cf-terraforming or manual zone file in git)
- Workers source in git?
- R2 buckets: lifecycle and replication?
- Page Rules / Security rules: documented somewhere outside Cloudflare?

---

## PHASE 6: SECRETS

- Local credentials/secrets vault (and any other secret stash): backed up encrypted? (Bitwarden, 1Password, pass)
- `.env.local` files: stored in a password manager?
- API keys rotation log: when was each key last rotated?
- SSH keys: have a recovery plan if the dev machine dies?

---

## PHASE 7: RESTORE TESTING

The thing nobody does. For each backup destination, when was the last successful test restore?

- Supabase: "Restore to a New Project" (paid plans, physical backups enabled; with PITR pick an exact timestamp), verify data, delete the project. It does NOT copy storage objects, Edge Functions, auth settings / API keys, Realtime settings or extension settings, and `pg_cron`/`pg_net` jobs start running immediately in the copy — disable outbound side effects first (source: https://supabase.com/docs/guides/platform/clone-project).
- Coolify volume: restore to a scratch path, diff against live.
- Git repo: clone from the mirror, build, run.

If no test in the last 90 days, treat backups as untested → effectively unknown.

---

## PHASE 8: RECOVERY PLAYBOOK

Confirm a written DR runbook exists per critical system answering:

1. Who runs the restore? (single bus-factor person = HIGH risk)
2. What credentials are needed and where are they stored?
3. What is the order of operations? (DB before app, DNS last, etc.)
4. How is data integrity verified after restore?
5. How are users notified?
6. What is the rollback if restore fails?

If no runbook → CRITICAL finding regardless of backup health.

---

## OUTPUT — REPORT

```
========================================
   BACKUP & DR AUDIT REPORT
   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Overall DR posture + worst-case scenario verdict]

## SYSTEMS INVENTORY
[Table: system | RPO target | RPO actual | RTO target | RTO actual | last test | verdict]

## CRITICAL GAPS
[Systems with no backup or unrecoverable in target window]

## HIGH GAPS
[Backups exist but untested, single bus-factor, no runbook]

## SECRETS STORE
[Status: protected / at-risk / unknown]

## RESTORE TEST LOG
[Last test per system, what passed/failed]

## RECOMMENDED RESTORE EXERCISE
[The next test to run]
```

---

## FIX KIT — write `BACKUP-FIXES.md`

For each gap, generate:
- Configuration change (enable PITR, increase retention, set up off-site copy)
- Code/config change for IaC (Cloudflare zone export, repo mirror push)
- Runbook stub (markdown template for the recovery playbook)
- Calendared test (next test date + scope)

Add `BACKUP-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

START NOW.
