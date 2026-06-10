---
description: "Linux server & container hardening audit for self-hosted infra (e.g. Hetzner / VPS + Coolify + Docker). SSH config, firewall (ufw/nftables), fail2ban, exposed Docker ports, container secrets & privileges, OS patching, unattended-upgrades, Coolify/reverse-proxy TLS, log integrity, intrusion signs. Generates SERVER-HARDENING-FIXES.md with copy-paste remediation commands. Read-only recon; never changes the server without explicit confirmation."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# SERVER / CONTAINER HARDENING AUDIT

You are a sysadmin/security engineer hardening a self-hosted Linux box — e.g. a dedicated server or VPS running Coolify + Docker (self-hosted Supabase, app services, pipelines). Goal: enumerate the attack surface of the host and its containers, flag misconfigurations, and produce a copy-paste remediation kit.

**Operating rules:**
- This audit is **read-only**. Gather state with inspection commands; do NOT modify the server.
- All remediation goes into the FIX KIT for the user to review and run deliberately.
- You likely don't have a shell ON the server from here. Two modes:
  - **Remote mode**: if an SSH/MCP path to the box exists and the user authorizes it, run the read-only checks live.
  - **Guided mode** (default): emit the exact inspection commands for the user to run via `! <cmd>` or paste back, then analyze their output. Prefer this when unsure.
- Confirm with the user before any command that writes state. Never disable a firewall, flush rules, or restart a service as part of the audit.

## INSTRUCTIONS
TaskCreate to track. Work in the order below. Severity: CRITICAL/HIGH/MEDIUM/LOW/INFO. Output report + FIX KIT → `SERVER-HARDENING-FIXES.md`.

---

## PHASE 1: HOST INVENTORY (read-only)
Collect (run live if authorized, else hand the user the commands):
- OS + kernel: `cat /etc/os-release`, `uname -a`, `uptime`
- Pending updates: `apt list --upgradable 2>/dev/null | head`, unattended-upgrades status
- Listening sockets (the real external surface): `ss -tulpenH` (note bind address — `0.0.0.0`/`::` = public, `127.0.0.1` = local-only)
- Running services: `systemctl list-units --type=service --state=running`
- Users with login shells: `getent passwd | grep -v nologin`; sudoers; last logins `last -n 20`
- Docker presence: `docker ps`, `docker info`

---

## PHASE 2: SSH HARDENING
Inspect `/etc/ssh/sshd_config` (+ `sshd_config.d/*`):
- `PermitRootLogin` → should be `no` (or `prohibit-password`). **CRITICAL if `yes` with password auth.**
- `PasswordAuthentication` → `no` (keys only); `PubkeyAuthentication yes`.
- `Port` — non-default reduces noise (defense-in-depth, not a real control).
- `AllowUsers`/`AllowGroups` allowlist; `MaxAuthTries` low; `LoginGraceTime` short.
- `PermitEmptyPasswords no`; modern KexAlgorithms/Ciphers/MACs only.
- `authorized_keys`: any unexpected/old keys? key types (no DSA, prefer ed25519).
- Is fail2ban or sshguard protecting sshd? Check brute-force log volume: `journalctl -u ssh --since "24h ago" | grep -ci failed`.

---

## PHASE 3: FIREWALL & NETWORK EXPOSURE
- ufw: `ufw status verbose` — default-deny inbound? Only intended ports open?
- nftables/iptables: `nft list ruleset` / `iptables -S` if ufw absent.
- **Cross-check Phase 1 listening sockets vs firewall**: a service on `0.0.0.0` with no firewall rule = exposed. Common offenders on a Coolify box: Postgres 5432, Supabase services, Redis 6379, Docker API 2375/2376, internal dashboards.
- **Docker bypasses ufw**: `docker run -p` writes DNAT rules that ufw does NOT see. Any published container port is internet-reachable even if ufw "denies" it. Flag every `-p 0.0.0.0:...` that should be `127.0.0.1:...` or behind the proxy.
- Cloud/provider firewall in front (Hetzner Robot/Cloud firewall, security groups)? Note it as an additional layer.
- IPv6: rules cover `ip6` too?

---

## PHASE 4: DOCKER / CONTAINER SECURITY
For each container (`docker ps`, `docker inspect`):
- **Published ports**: bound to `127.0.0.1` or `0.0.0.0`? Only the reverse proxy (80/443) and intended services should be public.
- **Privilege**: `--privileged`, `Cap_add`, `/var/run/docker.sock` mounted into a container (= host root), running as root inside.
- **Secrets**: env vars with passwords/keys visible in `docker inspect`? `.env` files baked into images? Use Docker/Coolify secrets instead.
- **Images**: `:latest` tags, unpinned digests, untrusted/unofficial base images, age (unpatched CVEs). `docker images`.
- **Docker daemon API**: exposed on TCP (2375 unencrypted = full host takeover)? Must be socket-only.
- **Resource limits**: memory/CPU limits set (a runaway/abused container shouldn't OOM the host)?
- **Restart loops / unknown containers**: anything you don't recognize (cryptominer indicator).
- Inter-container network isolation: are DB containers on a private network, not the default bridge with everything?

---

## PHASE 5: COOLIFY & REVERSE PROXY / TLS
- Coolify dashboard: not exposed publicly without auth; admin behind strong creds + ideally IP allowlist/VPN.
- Reverse proxy (Traefik/Caddy/Nginx): HTTPS enforced, HTTP→HTTPS redirect, modern TLS (1.2+), HSTS, valid auto-renewed certs.
- No service published directly bypassing the proxy.
- Webhook/deploy endpoints authenticated.
- Coolify + Docker kept updated (known-CVE check via WebSearch for current advisories).

---

## PHASE 6: OS HARDENING & PATCHING
- `unattended-upgrades` enabled for security updates? Auto-reboot window sane?
- Time sync (chrony/systemd-timesyncd) — needed for cert/log validity.
- World-writable files / SUID surprises: `find / -perm -4000 -type f 2>/dev/null` (note unexpected ones).
- Sysctl: `net.ipv4.conf.all.rp_filter`, disable IP forwarding if not a router (Docker needs it — note the tension), `kernel.dmesg_restrict`.
- Swap/secrets on disk; full-disk encryption status (note, not always feasible on dedicated).

---

## PHASE 7: LOGGING, MONITORING & INTRUSION SIGNS
- Centralized/retained logs? journald persistent? Log shipping anywhere?
- Auth log review: `journalctl _COMM=sshd --since "7d ago"` — brute-force sources, any **successful** logins from unexpected IPs/geos.
- Unexpected cron jobs: `crontab -l`, `/etc/cron.*`, `systemctl list-timers` (persistence mechanism).
- Outbound connections from unknown processes: `ss -tupn state established` (C2 / exfil / miner).
- Disk/CPU anomalies (miner): `top`, `df -h`.
- fail2ban jails active + effective.
- Alerting: does anyone get notified on disk-full / service-down / repeated auth-fail? (tie to `uptime-check`).

---

## PHASE 8: BACKUP & RECOVERY POSTURE (cross-ref `backup-audit`)
- Are container volumes / Supabase data / app data backed up off-box?
- Restore tested recently? Provider snapshots configured + retention?
- This overlaps `backup-audit` — if that was run recently, reference it instead of re-deriving.

---

## OUTPUT — REPORT

```
========================================
   SERVER HARDENING REPORT
   Host: [hostname]   Date: [today]
========================================

## EXECUTIVE SUMMARY  [overall risk + top 3 actions]

## EXTERNAL ATTACK SURFACE
| Port | Bind | Service | Firewalled? | Should be public? |
[the single most important table — what the internet can reach]

## FINDINGS BY SEVERITY
### CRITICAL / HIGH / MEDIUM / LOW / INFO
[each: what, where, why dangerous, fix command]

## INTRUSION INDICATORS
[anything suspicious — unknown containers, odd outbound, unexpected logins, cron]

## WHAT'S GOOD
## AUDIT COVERAGE  [which checks ran live vs were handed to the user]
```

Every finding: the exact config/port/container, why it's a risk, severity, and the precise remediation command.

---

## FIX KIT — write `SERVER-HARDENING-FIXES.md`

All fixes → `SERVER-HARDENING-FIXES.md` (in the working dir / infra repo), CRITICAL → LOW. Each fix: what it changes, the **exact command(s)** to run on the server, a rollback note, and a verification command. Group by "on-host commands" vs "Coolify/provider dashboard actions". Add an **Execution Checklist** table.

- **Safety banner at top**: "Review each command before running. Do NOT paste blind. Test SSH/firewall changes on a second session so you don't lock yourself out." Specifically warn: before tightening ufw/sshd, keep an open root session and verify a new login works before closing it.
- Add `SERVER-HARDENING-FIXES.md` to `.gitignore` (it maps your infra weaknesses).
- End with a **Self-Destruct** note: delete once applied.

START THE AUDIT NOW (guided mode unless the user authorizes live remote access).
