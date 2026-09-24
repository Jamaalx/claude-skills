#!/usr/bin/env bash
# Structural checks for the skill files — run locally or in CI (.github/workflows/lint.yml).
#
#   1. every commands/*.md starts with YAML frontmatter that has a non-empty `description:`
#   2. every commands/*.md is referenced from README.md
#   3. the skill count stated in README.md matches the number of files in commands/
#   4. no personal / sensitive data in commands/ and examples/ (see CONTRIBUTING.md):
#      credential-shaped strings, home-directory paths, real email addresses
#
# Exit code is non-zero if any check fails.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_DIR="$ROOT/commands"
README="$ROOT/README.md"

fail=0
err() { echo "  ✗ $*" >&2; fail=1; }
ok()  { echo "  ✓ $*"; }

if [ ! -d "$CMD_DIR" ]; then
  echo "✗ commands/ directory not found at $CMD_DIR" >&2
  exit 1
fi

echo "1. Frontmatter"
for f in "$CMD_DIR"/*.md; do
  name="$(basename "$f")"
  if [ "$(head -n 1 "$f")" != "---" ]; then
    err "$name: does not start with a YAML frontmatter block (---)"
    continue
  fi
  # Frontmatter = everything between the first line and the next '---'.
  fm="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$f")"
  if [ -z "$fm" ]; then
    err "$name: frontmatter block is empty or unterminated"
    continue
  fi
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)"
  # Strip surrounding quotes and whitespace.
  desc="$(printf '%s' "$desc" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" -e 's/[[:space:]]*$//')"
  if [ -z "$desc" ]; then
    err "$name: frontmatter has no non-empty description:"
  fi
done
[ "$fail" -eq 0 ] && ok "all skill files have frontmatter with a description"

echo "2. README references"
missing=0
for f in "$CMD_DIR"/*.md; do
  name="$(basename "$f")"
  if ! grep -qF "commands/$name" "$README"; then
    err "$name: not mentioned in README.md"
    missing=1
  fi
done
[ "$missing" -eq 0 ] && ok "every skill file is referenced in README.md"

echo "3. Skill count"
actual="$(find "$CMD_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
stated="$(grep -oE '^[0-9]+ production-grade' "$README" | head -n 1 | grep -oE '^[0-9]+' || true)"
if [ -z "$stated" ]; then
  err "README.md does not state a skill count ('<N> production-grade ...' on its intro line)"
elif [ "$stated" != "$actual" ]; then
  err "README.md says $stated skills, commands/ contains $actual"
else
  ok "README says $stated skills, commands/ contains $actual"
fi

echo "4. Sensitive data"
SCAN_DIRS=("$CMD_DIR")
[ -d "$ROOT/examples" ] && SCAN_DIRS+=("$ROOT/examples")
sens=0
# Credential-shaped strings (Anthropic/OpenAI, GitHub, AWS, Slack, Google, Supabase PAT, PEM keys).
secret_re='(sk-(ant-)?[A-Za-z0-9_-]{24,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sbp_[a-f0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
if hits="$(grep -rnoE "$secret_re" "${SCAN_DIRS[@]}")"; then
  err "credential-shaped string(s):"; printf '%s\n' "$hits" >&2; sens=1
fi
# Machine-specific home paths (placeholders like /Users/you or /home/user are fine).
if hits="$(grep -rnoE '(/Users/|/home/|C:\\Users\\)[A-Za-z0-9._-]+' "${SCAN_DIRS[@]}" \
    | grep -vE '(/Users/|/home/|Users\\)(you|user|username|me|example|<[^>]*>)$')"; then
  err "home-directory path(s) — use ~ or a placeholder:"; printf '%s\n' "$hits" >&2; sens=1
fi
# Email addresses other than obvious placeholders / public authorities.
email_allow='@(example\.(com|org|net)|x\.com|bar\.com|foo\.com|test\.com|dataprotection\.ro)$'
if hits="$(grep -rnoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "${SCAN_DIRS[@]}" | grep -viE "$email_allow")"; then
  err "email address(es) — use a placeholder such as user@example.com:"; printf '%s\n' "$hits" >&2; sens=1
fi
[ "$sens" -eq 0 ] && ok "no credentials, home paths or real email addresses in commands/ or examples/"

if [ "$fail" -ne 0 ]; then
  echo "" >&2
  echo "check-skills: FAILED" >&2
  exit 1
fi
echo ""
echo "check-skills: all checks passed ($actual skills)"
