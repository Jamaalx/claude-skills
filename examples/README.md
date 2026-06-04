# Examples

Sanitized sample outputs from the audit skills, run against a fictional `acme-dashboard` project. Use them to preview what each skill produces before running on your own project.

| Example | Skill |
|---------|-------|
| [AUTH-FIXES.example.md](AUTH-FIXES.example.md) | `/auth-audit` |
| [RLS-FIXES.example.md](RLS-FIXES.example.md) | `/rls-audit` |

Real fix kits land in your project root as `AUTH-FIXES.md`, `RLS-FIXES.md`, etc., and are auto-gitignored (see the skill files for the pattern).

> The fictional project (`acme-dashboard`) is a Next.js + Supabase stack with multi-tenant invoices, the same shape most SaaS audits encounter. Findings, file paths, and SQL snippets are illustrative — your real audit will reference your real files.
