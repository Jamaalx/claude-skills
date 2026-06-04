---
description: "Dependency audit: CVEs per locked version, outdated packages, breaking changes on majors, supply-chain risk (typosquatting, abandoned/transferred packages), license compliance, bundle bloat. Covers npm + Python (pip). Generates DEPS-FIXES.md with safe-update commands + breaking-change plan."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# DEPENDENCY AUDIT

You are a supply-chain security engineer. Goal: enumerate every dependency, find vulnerabilities tied to the EXACT locked version, identify safe upgrades vs breaking ones, flag supply-chain risks (typosquatting, abandoned/transferred packages, malicious postinstall scripts), and produce a `DEPS-FIXES.md` with copy-paste-ready commands.

Run all phases. Use parallel agents for the per-package CVE research. Track progress with tasks.

---

## PHASE 1: INVENTORY

Identify package managers in use:

- Node.js: `package.json` + `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`
- Python: `requirements.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile.lock`
- Also note: `bun.lockb`, `composer.json`, `Cargo.toml`, `go.mod`

For each, list direct dependencies vs transitive. Note which packages are dev-only vs runtime.

---

## PHASE 2: VULNERABILITY SCAN

Run for the exact lockfile state:

```
# Node
npm audit --json
# (or pnpm audit --json / yarn audit --json)

# Python
pip-audit -r requirements.txt --format json
# (install if missing: pip install pip-audit)
```

For each finding:
- CVE id, CVSS score, affected version range, fixed version
- Path through transitive deps (`npm audit` shows it)
- Is the vulnerable code path actually reachable? (quick grep for the affected function names in our code)

---

## PHASE 3: OUTDATED PACKAGES

```
npm outdated --json
pip list --outdated --format=json
```

Categorize each:
- **Patch** (X.Y.Z → X.Y.Z+1): always safe to take.
- **Minor** (X.Y.Z → X.Y+1.0): usually safe; check changelog.
- **Major** (X.Y.Z → X+1.0.0): always inspect changelog / migration guide.

For majors, WebFetch the changelog or release notes; summarize breaking changes relevant to our usage (grep our code for the affected APIs).

---

## PHASE 4: SUPPLY-CHAIN RISK

For each direct dependency, especially low-popularity ones:

1. **Typosquatting**: any package whose name is one Levenshtein-edit from a popular one we don't intend to use?
2. **Abandoned / transferred**: WebSearch "<package-name> npm deprecated", "<package-name> taken over", check last publish date. If maintainer transferred ownership recently, flag.
3. **Malicious install scripts**: grep node_modules for `postinstall`, `preinstall`, `install` in `package.json` of dependencies; flag any that run shell, network, or eval.
4. **Tiny / single-maintainer / no GH repo**: high-risk.
5. **Compromised packages**: WebSearch recent npm advisories for any package in our list.

---

## PHASE 5: LICENSE COMPLIANCE

```
npx license-checker --json --excludePrivatePackages
# or: pnpm licenses list
pip-licenses --format=json
```

Cross-reference licenses with the project's own license (read LICENSE file). Flag:

- GPL / AGPL / LGPL in a commercial/MIT project.
- Packages without a license at all.
- Custom / non-OSI licenses.
- Attribution requirements not being met (BSD, MIT require notice).

---

## PHASE 6: BUNDLE BLOAT (web projects)

If Next.js / Vite / Webpack:

- Run `next build` and inspect `.next/analyze` if available; otherwise `npx next-bundle-analyzer` or `npx vite-bundle-visualizer`.
- Identify packages > 100 KB gzipped in client bundle.
- Suggest lighter alternatives (e.g., `date-fns` instead of `moment`, native fetch instead of `axios` if only used server-side).
- Flag packages imported on client side that should only be server-side.

---

## PHASE 7: UNUSED & DUPLICATE

- `npx depcheck` — packages declared in `package.json` but not imported anywhere.
- `npx npm-check-duplicates` or inspect lockfile — same package at multiple versions in tree.
- For Python: `pip check` for conflicts.

---

## PHASE 8: FRAMEWORK-SPECIFIC CHECKS

If Next.js: check the installed version against current stable, note if on canary/beta. Read `node_modules/next/dist/docs/` for active deprecation notices touching code we use.

If Supabase JS SDK: ensure both `@supabase/supabase-js` and `@supabase/ssr` are recent and compatible.

If React: peer-dep consistency across React Router / Tanstack / etc.

---

## OUTPUT — REPORT

```
========================================
   DEPENDENCY AUDIT REPORT
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[risk rating + 2-3 sentence verdict]

## CRITICAL CVEs (drop everything)
[list with package, version, CVE, fix version, exploitability]

## HIGH / MEDIUM / LOW CVEs

## OUTDATED — SAFE TO UPDATE
[patch + minor that don't change behavior]

## OUTDATED — REQUIRES REVIEW (majors)
[major version bumps with changelog summary + grep-based impact assessment]

## SUPPLY-CHAIN RISK
[suspicious packages, abandoned maintainers, malicious install scripts]

## LICENSE ISSUES
[GPL contamination, missing licenses, attribution gaps]

## BUNDLE BLOAT
[heavy packages + lighter alternatives]

## UNUSED / DUPLICATED
[depcheck + lockfile duplicates]

## AUDIT COVERAGE
```

---

## FIX KIT — write `DEPS-FIXES.md`

Generate copy-paste-ready commands, ordered by severity:

- One command line for the safe-batch update (`npm update <list>` of all safe patches/minors).
- Per-major-bump: a self-contained prompt that includes changelog summary + grep results + suggested code changes.
- Per-CVE: the exact `npm install <pkg>@<fixed-version>` command and any code changes needed.
- For supply-chain swaps: remove + install replacement command.
- For removals (unused): `npm uninstall <list>`.

Add `DEPS-FIXES.md` to `.gitignore`. Include execution checklist table at top. Self-destruct note at bottom.

---

## OPTIONAL: APPLY SAFE UPDATES

If user confirms (`/deps-audit fix`):
- Run the safe-batch update.
- Run tests / typecheck to verify.
- Stop and ask before any major bump.

START NOW.
