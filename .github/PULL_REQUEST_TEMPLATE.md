## What this PR does

One paragraph. For a new skill or a new check: one example finding it catches.

## Checklist (see [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md))

- [ ] `commands/<skill>.md` has frontmatter with a specific one-line `description:` and `allowed-tools:`
- [ ] Body follows the [`auth-audit.md`](../blob/main/commands/auth-audit.md) structure: intro, 8-15 phases, `OUTPUT — REPORT`, `FIX KIT — write <NAME>-FIXES.md`, optional `APPLY` gated behind confirmation
- [ ] README table row added / updated, with cadence
- [ ] Kit filename covered by the `*-FIXES.md` rule in `.gitignore`
- [ ] `/skills-doctor` run locally, no structural issues
- [ ] `bash scripts/check-skills.sh` passes
- [ ] No personal / client info: no real emails, names, company identifiers, machine paths, live IPs / hostnames / internal URLs, credentials
