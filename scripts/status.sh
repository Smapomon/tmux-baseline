#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$PLUGIN_DIR/state/baseline-state.txt"
STATUS_TMP="$PLUGIN_DIR/state/.status_tmp.$$"

if [ ! -f "$STATE_FILE" ]; then
  tmux display-message "baseline: no saved state found"
  exit 0
fi

unescape_field() {
  local value="$1"
  local placeholder=$'\037'

  value=${value//\\\\/$placeholder}
  value=${value//\\t/$'\t'}
  value=${value//\\n/$'\n'}
  value=${value//\\r/$'\r'}
  value=${value//$placeholder/\\}

  printf '%s' "$value"
}

shorten_path() {
  local path="$1"
  if [[ "$path" == "$HOME"* ]]; then
    printf '~%s' "${path#"$HOME"}"
  else
    printf '%s' "$path"
  fi
}

saved_at=""
window_count=0

declare -a session_names=()
declare -A session_seen=()
declare -A session_window_count=()
declare -a window_lines=()
declare -a window_owners=()

while IFS=$'\t' read -r kind f1 f2 f3 f4 extra; do
  [ -z "$kind" ] && continue

  case "$kind" in
    '#'*)
      if [[ "$kind $f1" == "# saved_at="* ]]; then
        saved_at="${kind#\# saved_at=}"
      elif [[ "$f1" == saved_at=* ]]; then
        saved_at="${f1#saved_at=}"
      fi
      ;;
    session)
      [ -z "$f1" ] && continue
      session_name="$(unescape_field "$f1")"
      if [ -z "${session_seen[$session_name]}" ]; then
        session_seen[$session_name]=1
        session_names+=("$session_name")
        session_window_count[$session_name]=0
      fi
      ;;
    window)
      [ -z "$f1" ] || [ -z "$f2" ] || [ -z "$f3" ] && continue

      session_name="$(unescape_field "$f1")"
      window_index="$(unescape_field "$f2")"
      window_name="$(unescape_field "$f3")"
      window_path="$(unescape_field "$f4")"

      if [ -z "${session_seen[$session_name]}" ]; then
        session_seen[$session_name]=1
        session_names+=("$session_name")
        session_window_count[$session_name]=0
      fi

      short_path="$(shorten_path "$window_path")"
      window_owners+=("$session_name")
      window_lines+=("$(printf '  %s: %-14s %s' "$window_index" "$window_name" "$short_path")")
      session_window_count[$session_name]=$(( ${session_window_count[$session_name]} + 1 ))

      window_count=$((window_count + 1))
      ;;
  esac
done < "$STATE_FILE"

{
  printf 'baseline - saved state\n'
  printf '%0.s━' {1..40}
  printf '\n'

  if [ -n "$saved_at" ]; then
    printf 'saved at: %s\n' "$saved_at"
  fi

  printf '%d sessions, %d windows\n' "${#session_names[@]}" "$window_count"

  for session_name in "${session_names[@]}"; do
    wc="${session_window_count[$session_name]}"
    if [ "$wc" -eq 1 ]; then
      printf '\n%s (%d window)\n' "$session_name" "$wc"
    else
      printf '\n%s (%d windows)\n' "$session_name" "$wc"
    fi

    for i in "${!window_owners[@]}"; do
      if [ "${window_owners[$i]}" = "$session_name" ]; then
        printf '%s\n' "${window_lines[$i]}"
      fi
    done
  done
} > "$STATUS_TMP"

tmux display-popup -E -w 70% -h 70% -T " baseline status " \
  bash -c "less -R -F -X '$STATUS_TMP'; rm -f '$STATUS_TMP'"
