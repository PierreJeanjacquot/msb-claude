#!/usr/bin/env bash
set -euo pipefail

SRC="${SKILLS_SRC:-$HOME/.host/.agents/skills}"
DEST="${SKILLS_DEST:-$HOME/.claude/skills}"

added=0
removed=0
skipped=0

# No source dir (e.g. host mount not present) — nothing to link, stay silent
if [ ! -d "$SRC" ]; then
  exit 0
fi

mkdir -p "$DEST"

# Add missing symlinks for skill directories in SRC (skip dotfiles and plain files)
while IFS= read -r -d '' entry; do
  name=$(basename "$entry")
  link="$DEST/$name"

  # Nothing at $link yet — safe to create the symlink
  if [ ! -e "$link" ] && [ ! -L "$link" ]; then
    ln -s "$entry" "$link"
    added=$((added + 1))
  # A symlink is already there — check whether it's ours before touching it
  elif [ -L "$link" ]; then
    current_target=$(readlink -f "$link" 2>/dev/null || true)
    real_entry=$(readlink -f "$entry" 2>/dev/null || true)
    # Symlink exists but points somewhere other than this SRC entry —
    # someone else manages it, don't touch it
    if [ "$current_target" != "$real_entry" ]; then
      echo "warn: $link is a symlink pointing elsewhere ($current_target), leaving it alone" >&2
      skipped=$((skipped + 1))
    fi
  else
    # A real file/dir already sits at $link — leave user-owned content alone
    echo "warn: $link already exists and is not a symlink, leaving it alone" >&2
    skipped=$((skipped + 1))
  fi
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0)

# Remove stale symlinks: managed by us (target resolves under SRC) but source is gone
while IFS= read -r -d '' link; do
  target=$(readlink -f "$link" 2>/dev/null || true)
  real_src=$(readlink -f "$SRC" 2>/dev/null || true)

  case "$target" in
    "$real_src"/*)
      # Target was under SRC but no longer exists — the skill was removed upstream
      if [ ! -e "$target" ]; then
        unlink "$link"
        removed=$((removed + 1))
      fi
      ;;
  esac
done < <(find "$DEST" -mindepth 1 -maxdepth 1 -type l -print0)

# Nothing changed and nothing to warn about — no output needed
if [ "$added" -eq 0 ] && [ "$removed" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  exit 0
fi

msg="relink-skills: +$added added, -$removed removed, $skipped skipped (source $SRC)"

# Skill discovery runs before SessionStart hooks finish, so any symlinks we
# just created/removed above wouldn't show up until a full restart unless we
# ask Claude Code to rescan (reloadSkills, added in v2.1.152). Only request it
# when symlinks actually changed — a skip-only run has nothing new to pick up.
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  reload=true
else
  reload=false
fi

# hookSpecificOutput is set to null (then stripped) when no rescan is needed
jq -n --arg msg "$msg" --argjson reload "$reload" '
  {
    systemMessage: $msg,
    hookSpecificOutput: (
      if $reload
      then { hookEventName: "SessionStart", reloadSkills: true }
      else null
      end
    )
  }
  | with_entries(select(.value != null))
'
