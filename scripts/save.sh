#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$PLUGIN_DIR/state"
STATE_FILE="$STATE_DIR/baseline-state.txt"

escape_field() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//$'\t'/\\t}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  printf '%s' "$value"
}

mkdir -p "$STATE_DIR" || {
  tmux display-message "baseline: failed to create state directory"
  exit 1
}

tmp_file="$STATE_FILE.tmp.$$"
saved_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
session_count=0
window_count=0

{
  printf '# baseline_state_v1\n'
  printf '# saved_at=%s\n' "$saved_at"

  while IFS= read -r session_name; do
    [ -z "$session_name" ] && continue
    session_count=$((session_count + 1))
    printf 'session\t%s\n' "$(escape_field "$session_name")"
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)

  while IFS= read -r window_id; do
    [ -z "$window_id" ] && continue

    session_name="$(tmux display-message -p -t "$window_id" '#{session_name}')"
    window_index="$(tmux display-message -p -t "$window_id" '#{window_index}')"
    window_name="$(tmux display-message -p -t "$window_id" '#{window_name}')"
    window_path="$(tmux display-message -p -t "$window_id" '#{pane_current_path}')"

    window_count=$((window_count + 1))
    printf 'window\t%s\t%s\t%s\t%s\n' \
      "$(escape_field "$session_name")" \
      "$(escape_field "$window_index")" \
      "$(escape_field "$window_name")" \
      "$(escape_field "$window_path")"
  done < <(tmux list-windows -a -F '#{window_id}' 2>/dev/null)
} > "$tmp_file"

if mv "$tmp_file" "$STATE_FILE"; then
  tmux display-message "baseline: saved $session_count sessions and $window_count windows"
else
  rm -f "$tmp_file"
  tmux display-message "baseline: failed to write state file"
  exit 1
fi
