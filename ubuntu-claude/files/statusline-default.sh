#!/usr/bin/env bash

# This is the default status line, create `$HOME/.claude/statusline.sh` to override default

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
rate_five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

BAR_WIDTH=20

# formats a token count as "X.Yk" or "X.YM", trimming a trailing ".0"
fmt_tokens() {
  LC_ALL=C awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { v = n / 1000000; unit = "M" }
    else { v = n / 1000; unit = "k" }
    s = sprintf("%.1f", v)
    sub(/\.0$/, "", s)
    printf "%s%s", s, unit
  }'
}

# render a compact progress bar: usage_pct label
# e.g. render_bar 38 "Session"  →  Session ████░░░░░░░░░░░░░░░░ 38%
render_bar() {
  local pct="$1"
  local label="$2"
  local pct_int
  pct_int=$(LC_ALL=C printf '%.0f' "$pct")

  # color only at 50%+
  local color reset
  if [ "$pct_int" -ge 50 ]; then
    color='\033[00;33m'   # yellow
    reset='\033[0m'
  else
    color='' reset=''
  fi

  local filled empty
  filled=$(( pct_int * BAR_WIDTH / 100 ))
  [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
  empty=$(( BAR_WIDTH - filled ))

  local bar="" i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$(( i + 1 )); done

  printf '%b%s %s %d%%%b' "$color" "$label" "$bar" "$pct_int" "$reset"
}

# ── Line 1: user@host:cwd ───────────────────────────────────────────

# [📦 sandbox-name] (only in sandbox)
if [ -n "$MSB_HOSTNAME" ]; then
  printf '\033[01;33m[MSB📦%s]\033[00m ' "$MSB_HOSTNAME"
fi

# user@host:cwd
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$(whoami)" "$(hostname -s)" "$cwd"

# ── Line 2: model + context ──────────────────────────────────────────────────

printf '\n'

# model (strip any parenthetical suffix, e.g. " (1M context)")
if [ -n "$model" ]; then
  model_clean=$(echo "$model" | sed -E 's/[[:space:]]*\([^)]*\)[[:space:]]*$//')
  printf '\033[00;35m[%s]\033[00m' "$model_clean"
fi

# context: used tokens / total context size - used %
if [ -n "$ctx_used" ]; then
  ctx_int=$(LC_ALL=C printf '%.0f' "$ctx_used")
  used_fmt=""
  total_fmt=""
  [ -n "$ctx_tokens" ] && used_fmt=$(fmt_tokens "$ctx_tokens")
  [ -n "$ctx_size" ] && total_fmt=$(fmt_tokens "$ctx_size")

  if [ "$ctx_int" -ge 80 ]; then
    color='\033[01;31m'
  elif [ "$ctx_int" -ge 50 ]; then
    color='\033[00;33m'
  else
    color='\033[00;32m'
  fi

  if [ -n "$used_fmt" ] && [ -n "$total_fmt" ]; then
    printf ' %b%s/%s (%s%%)%b' "$color" "$used_fmt" "$total_fmt" "$ctx_int" '\033[00m'
  else
    printf ' %b(%s%%)%b' "$color" "$ctx_int" '\033[00m'
  fi
fi

# ── Line 3: plan consumption progress bars (only when rate limit data exists) ─

if [ -n "$rate_seven_day" ] || [ -n "$rate_five_hour" ]; then
  printf '\n'
  if [ -n "$rate_seven_day" ]; then
    render_bar "$rate_seven_day" "Week"
  fi
  if [ -n "$rate_seven_day" ] && [ -n "$rate_five_hour" ]; then
    printf ' | '
  fi
  if [ -n "$rate_five_hour" ]; then
    render_bar "$rate_five_hour" "Session"
  fi
fi
