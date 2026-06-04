---
description: "Dead code & unused-deps audit: unused files/exports/components, unused npm/pip packages, duplicated logic, commented-out blocks, orphan API routes, dangling assets. Generates DEAD-CODE-FIXES.md with safe-remove plan."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, TaskCreate, TaskUpdate]
---

# DEAD CODE & UNUSED-DEPS AUDIT

You are a code-quality engineer cleaning house. Goal: find code that is no longer referenced but still loaded, packages installed but never imported, files that nobody links to, and large commented-out blocks. Output a report + `DEAD-CODE-FIXES.md` with safe removal commands.

Removal is risky — anything dynamically imported, used at runtime via string lookup, or referenced from outside the repo (CMS template, infra script) can look "dead" but isn't. Be conservative; flag false-positive risks.

---

## PHASE 1: UNUSED FILES

For TypeScript / JavaScript:

```
npx knip --reporter json
# or: npx ts-prune
# or: npx unimported
```

Cross-reference findings:
- Files reported by all tools → high confidence dead.
- Files reported by only one tool → manual check.

Manual sanity checks:
- Is the file referenced via `dynamic import`, `require(varname)`, or string-based lookup? Grep for the basename.
- Is it the entry point of an API route? (Next.js `app/api/**/route.ts` is dead only if no client / external caller hits the path.)
- Is it loaded by config / infra (`vercel.json`, `wrangler.toml`, `Dockerfile`)?

---

## PHASE 2: UNUSED EXPORTS

```
npx ts-prune
# or knip with --include exports
```

For each unused export:
- Internal helper that's only used in its own file → can be made non-exported.
- Component / function with no importer → candidate for deletion.
- Re-export barrel (`index.ts`) entries with no consumer.

---

## PHASE 3: UNUSED DEPENDENCIES

```
npx depcheck --json
# Python:
pip-autoremove --list   # if installed, else manual
# Cross-check requirements vs imports:
# rg -t py "^(import|from) (\w+)" | parse package names | compare against requirements
```

Categorize:
- True unused (no import anywhere) → safe-remove.
- Used only via plugin config (`eslint-plugin-*`, `@types/*`) — confirm via config files.
- Transitively required by something else → keep.

---

## PHASE 4: DEAD CSS / TAILWIND

For Tailwind: it already tree-shakes by default. Check `tailwind.config.*` content globs cover ALL source folders (otherwise true-positive classes look "unused" and get purged in prod — different issue, flag separately).

For non-Tailwind CSS: `npx purgecss --css ... --content ...` then diff to find unused selectors.

For component libraries (shadcn etc.): components copy-pasted into the repo that no page imports → dead.

---

## PHASE 5: ORPHAN API ROUTES & PAGES

For each route under `app/api/**/route.ts` or `pages/api/**`:
- Grep for the route path in the codebase (frontend fetch, external bot, etc.).
- Grep in adjacent / sibling projects in the same workspace (microservices, bots, dashboards) if the user confirms.
- If no caller is found, mark as candidate.

False-positive risk: external consumers (webhooks, integrations) — verify with the user before removing.

---

## PHASE 6: COMMENTED-OUT CODE BLOCKS

Grep for large commented-out blocks (>10 lines of consecutive `//` or `/* */`). These are technical debt; either restore with explanation or delete.

```
rg -n -U --multiline '^//.*\n(//.*\n){9,}'
rg -n -U --multiline '/\*[\s\S]{500,}?\*/'
```

---

## PHASE 7: ORPHAN ASSETS

For `public/` directory:
- Image / font / SVG not referenced anywhere in source or CSS → dead.
- Generated files (sitemap.xml, robots.txt) — keep.

```
# crude: find every file in public/, grep for its basename in src/
```

---

## PHASE 8: DUPLICATE LOGIC

Run `jscpd` (or similar) to find copy-pasted blocks across files:

```
npx jscpd ./src --reporters json
```

Each duplication is a refactor candidate (extract helper) or evidence of an older copy that should be deleted.

---

## PHASE 9: STALE FEATURE FLAGS / ENV BRANCHES

Grep for:
- `if (process.env.FEATURE_X === 'true')` where `FEATURE_X` is always true (or always missing) in prod.
- `if (false)` / `if (0)` literally dead.
- Long-dormant A/B branches.

---

## OUTPUT — REPORT

```
========================================
   DEAD CODE / UNUSED AUDIT
   Project: [name]   Date: [today]
========================================

## SUMMARY
[X files, Y exports, Z packages, N KB potentially removable]

## HIGH-CONFIDENCE DEAD
[Triple-confirmed by tools + manual]

## LIKELY DEAD (1-2 tools confirm)
[Needs human eyeball]

## POSSIBLY DEAD (low confidence)
[Could be dynamically loaded; check before removing]

## UNUSED DEPENDENCIES
[Package | size | safe-remove command]

## DUPLICATE CODE
[File A vs File B | lines | refactor suggestion]

## COMMENTED-OUT BLOCKS
[File | line range | recommendation]

## ORPHAN ASSETS
[File | size]

## STALE FLAGS
[Flag | last referenced]

## AUDIT COVERAGE
```

---

## FIX KIT — write `DEAD-CODE-FIXES.md`

Order: highest-confidence first.

For each removal item:
- File path / package name
- Confidence level: HIGH / MEDIUM / LOW
- Suggested action (delete file / remove export / `npm uninstall X`)
- False-positive risks
- Verification step (build + typecheck + smoke test after removal)

Group safe-remove items into batches that can be applied at once and re-tested.

Add `DEAD-CODE-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

---

## OPTIONAL: APPLY

Only on `/dead-code fix` and only for HIGH-confidence items in the first pass. Run `npm run build && npx tsc --noEmit` after each batch. Stop on any failure.

Never auto-remove API routes or assets without user OK — too easy to break external integrations.

START NOW.
