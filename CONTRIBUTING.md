# Contributing

Thanks for considering a contribution.

## Filing issues

- **Bug** — a skill misfires (referenced tool no longer exists, query syntax broke, fix kit produces invalid output). Include the skill name, the exact failure, and the project stack you ran it on.
- **Request a new skill** — open an issue describing the audit domain and one concrete example finding it should catch.
- **Request a check inside an existing skill** — same format, link the skill.

## Adding a skill

1. Create `commands/your-skill.md` with this frontmatter:
   ```yaml
   ---
   description: "One-line scope — used by Claude to decide when to invoke. Be specific."
   allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, TaskCreate, TaskUpdate]
   ---
   ```
2. Body structure — follow [`auth-audit.md`](commands/auth-audit.md) as the reference:
   - One short intro paragraph.
   - 8-15 phases, each with a clear scope. Use parallel agents where phases are independent.
   - One `OUTPUT — REPORT` section with the report format.
   - One `FIX KIT — write <NAME>-FIXES.md` section showing the prompt format.
   - Optional `APPLY` section gated behind explicit user confirmation.
3. Add the skill to the README table with cadence.
4. Add the kit filename to the project `.gitignore` rule.
5. Run `/skills-doctor` locally to check for structural issues.
6. Open a PR with a one-paragraph description and one example finding the skill catches.

## Avoiding personal / client info in skills

This repo is public. Before submitting:

- No real emails, names, company identifiers, CUI/VAT numbers, addresses.
- No internal project names. Use generic placeholders.
- No paths from your machine (`C:\Users\you\...`, `/Users/you/...`). Use `~/.claude/commands/...` or `%USERPROFILE%\.claude\commands\...`.
- No live IPs, hostnames, internal URLs.
- No real credentials, anywhere, ever.

The maintainer runs `git diff` against a sensitive-pattern grep before merging.

## License

By contributing, you agree your changes are licensed under [MIT](LICENSE).
