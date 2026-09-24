#!/usr/bin/env bash
# Installer for claude-skills — copies all skills into ~/.claude/commands/
set -euo pipefail

DEST="${HOME}/.claude/commands"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/commands"

if [ ! -d "$SRC" ]; then
  echo "✗ commands/ directory not found at $SRC" >&2
  exit 1
fi

force=0
for arg in "$@"; do
  case "$arg" in
    --force|-f) force=1 ;;
    -h|--help)
      echo "Usage: $0 [--force]   (--force overwrites skills you have edited locally)"
      exit 0 ;;
    *) echo "✗ unknown argument: $arg (try --help)" >&2; exit 2 ;;
  esac
done

mkdir -p "$DEST"

installed=0
skipped=0

for f in "$SRC"/*.md; do
  name=$(basename "$f")
  target="$DEST/$name"
  if [ "$force" -eq 0 ] && [ -e "$target" ] && ! cmp -s "$f" "$target"; then
    printf "  • %-24s exists with local changes — leaving as-is. Re-run with --force to overwrite.\n" "$name"
    skipped=$((skipped + 1))
    continue
  fi
  cp "$f" "$target"
  installed=$((installed + 1))
done

echo ""
echo "✓ Installed $installed skill(s) to $DEST"
if [ "$skipped" -gt 0 ]; then
  echo "  $skipped skipped (already present with local changes; use --force to overwrite)"
fi
echo ""
echo "Open Claude Code and type / to see the new commands."
