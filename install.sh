#!/usr/bin/env bash
# Installer for claude-skills — copies all skills into ~/.claude/commands/
set -euo pipefail

DEST="${HOME}/.claude/commands"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/commands"

if [ ! -d "$SRC" ]; then
  echo "✗ commands/ directory not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

installed=0
skipped=0

for f in "$SRC"/*.md; do
  name=$(basename "$f")
  target="$DEST/$name"
  if [ -e "$target" ]; then
    if ! cmp -s "$f" "$target"; then
      printf "  • %-24s exists with local changes — leaving as-is. Re-run with --force to overwrite.\n" "$name"
      skipped=$((skipped + 1))
      continue
    fi
  fi
  cp "$f" "$target"
  installed=$((installed + 1))
done

if [[ "${1:-}" == "--force" ]]; then
  for f in "$SRC"/*.md; do
    cp "$f" "$DEST/"
  done
  installed=$(ls "$SRC"/*.md | wc -l | tr -d ' ')
  skipped=0
fi

echo ""
echo "✓ Installed $installed skill(s) to $DEST"
[ "$skipped" -gt 0 ] && echo "  $skipped skipped (already present with local changes; use --force to overwrite)"
echo ""
echo "Open Claude Code and type / to see the new commands."
