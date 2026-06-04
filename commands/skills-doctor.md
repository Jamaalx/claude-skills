---
description: "Audit ALL user slash commands in ~/.claude/commands/: outdated tool references, stale framework versions, broken MCP names, redundant/overlapping skills, missing recent best-practices. Generates SKILLS-FIXES.md with per-skill update plan. Run quarterly."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate]
---

# SKILLS DOCTOR — meta-audit of slash commands

You are a tooling engineer auditing the user's library of slash commands (skills). Goal: make sure every skill is current, references tools that still exist, has not been overtaken by a newer/better alternative, and isn't a redundant duplicate of another skill.

Output: report + `SKILLS-FIXES.md` with per-skill update plan.

This is `audit-update` on steroids — `audit-update` only refreshes the 4 main audit skills with web research; this one inspects EVERY user skill and flags structural issues.

---

## PHASE 1: INVENTORY

List every skill file:

```
ls ~/.claude/commands/*.md
# Windows PowerShell: Get-ChildItem $env:USERPROFILE\.claude\commands\*.md
```

For each, read frontmatter (`description`, `allowed-tools`) and the body. Note:
- File name and slug
- Description
- Last modified date (git mtime if in a repo, else fs mtime)
- Length / complexity
- Domain (audit / generation / maintenance / utility)

If the project has skills under a `.claude/skills/` directory in addition, inventory those too.

---

## PHASE 2: TOOL REFERENCE FRESHNESS

For each skill's `allowed-tools`:

- Compare the listed MCP tool names against the CURRENT MCP catalog (from the prompt's deferred-tool list shown in this session, or by listing connected MCP servers).
- Flag tools that no longer exist (renamed, removed, server uninstalled).
- Flag wildcards (`mcp__foo__*`) that match nothing.

In the skill body, grep for hardcoded tool names that may have changed:
- `mcp__claude_ai_SupaBase__*` — these names changed historically; verify current ones.
- Old plugin names referenced in prose.
- CLI commands that may have been renamed (`pnpm audit` flag changes, `next-bundle-analyzer` rename, `pip-audit` arg changes).

---

## PHASE 3: FRAMEWORK / VERSION STALENESS

For each skill that references specific framework versions, tools, or APIs:

- WebSearch for the latest stable version of the framework / lib mentioned.
- If the skill references "Next.js 14 / 15 / etc.", check current major and note migration.
- WCAG 2.2 → 2.3? OWASP Top 10 → newer edition?
- Supabase Auth → still GoTrue, or migrated?
- Postgres major bump that changes the queries we suggest?
- Node LTS line?

For each version-sensitive claim in a skill, note: still current / mildly stale / replace.

---

## PHASE 4: OVERLAP & REDUNDANCY

Build a matrix: skill × topic. Look for skills that cover overlapping ground:

- `security-audit` already covers RLS (Phase 10a). Does `rls-audit` add enough beyond it? (Yes — deeper, with fix-kit. Document this in skill description so users know which to pick.)
- `auth-audit` overlaps `security-audit` Phase 4c. Same — keep both, clarify trigger.
- `prod-readiness` overlaps `security-audit` (secret/RLS check). Different: prod-readiness is fast/gate; security-audit is deep/periodic.

Flag genuine duplicates (same scope, same depth) vs intentional split (different cadence or focus).

Suggest cross-referencing in descriptions: "for deep audit run X, for quick gate run Y".

---

## PHASE 5: STRUCTURAL CONSISTENCY

Check each skill against the house style:

- Frontmatter has `description` and `allowed-tools`?
- Description starts with a clear action verb / one-line scope?
- Audit skills end with a "FIX KIT — write `*-FIXES.md`" phase?
- `*-FIXES.md` files added to `.gitignore` consistently?
- Self-destruct note in the fix kit?
- Optional `apply` mode documented?
- Tasks tracked with TaskCreate where multi-step?

Flag skills missing any standard piece.

---

## PHASE 6: DEAD / UNUSED SKILLS

For each skill:
- When was it last invoked? (Search `~/.claude/projects/*` transcripts for `<command-name>X</command-name>` mentions — best-effort.)
- Is the description so specific that it only applied to a one-off project that no longer exists?

If a skill hasn't been used in 6+ months AND its scope is obsolete, suggest deletion or archival.

---

## PHASE 7: GAPS

Cross-check the user's project list (from memory or active projects in the workspace) against the skill library. Is anything obvious missing?

Examples of gaps to suggest if missing:
- i18n audit (for projects with multiple languages)
- Email deliverability audit (if the project sends transactional/marketing email)
- Cron / scheduled-job audit
- SLO / error-budget review
- Onboarding skill for new client/project setup

Suggest 2-3 net-new skills max — quality over quantity.

---

## PHASE 8: WEB RESEARCH

For each major domain represented in the skill library, WebSearch:

- "WCAG 2.3 release" / "WCAG 2.2 updates 2026"
- "OWASP Top 10 2025" / "OWASP API Security Top 10"
- "Supabase RLS best practices 2026"
- "@supabase/ssr breaking changes"
- "Next.js 16 security" (or whatever current major)
- "npm supply-chain attacks 2026"
- "ANSPDCP cookies guidance update"

Use this to inform Phase 3 staleness verdicts.

---

## OUTPUT — REPORT

```
========================================
   SKILLS DOCTOR REPORT
   Date: [today]   Skills inventoried: [N]
========================================

## EXECUTIVE SUMMARY
[Overall health + top 3 actions]

## SKILL INVENTORY
| Skill | Updated | Verdict | Issues |
|-------|---------|---------|--------|

## CRITICAL UPDATES NEEDED
[Skills referencing dead tools / wrong APIs — will fail when invoked]

## STALE — UPDATE RECOMMENDED
[Out-of-date best-practice or version refs]

## OVERLAPS
[Pairs of skills with redundant scope — recommend merge or clarify descriptions]

## STRUCTURAL ISSUES
[Missing frontmatter, missing fix-kit phase, etc.]

## DEAD / UNUSED
[Skills not invoked in 6+ months and arguably obsolete]

## SUGGESTED NEW SKILLS
[2-3 gaps with one-line rationale each]

## RESEARCH FINDINGS (Phase 8 synthesis)
[Domain | finding | which skills are affected]

## AUDIT COVERAGE
```

---

## FIX KIT — write `SKILLS-FIXES.md`

NOTE: this kit lives in `~/.claude/` (NOT a project directory), since the target is the skills library itself. Add `SKILLS-FIXES.md` to a gitignore if the directory is versioned (Claude's user-config directory is typically NOT in git, so this may be moot — confirm before writing).

For each skill needing an update:

```
### FIX-N: [skill-name] — [short title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Type:** edit | replace | merge | archive | new
**File:** ~/.claude/commands/<skill>.md

**Issue:**
[What's wrong]

**Proposed change:**
[Specific diff or new text block, ready to paste]

**Verification:**
[Re-read the skill, invoke once on a sandbox project]
```

Order: CRITICAL (broken tool refs) → HIGH (stale frameworks) → MEDIUM (overlap clarification) → LOW (style polish).

---

## OPTIONAL: APPLY UPDATES

On `/skills-doctor fix`, apply edits one skill at a time. After each edit, ask the user to confirm before moving on (skills are personal config — never bulk-rewrite without confirmation).

Skill descriptions are part of the skill-discovery prompt; rewriting them changes what triggers them. Coordinate with the user.

START NOW.
