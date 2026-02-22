#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$PLUGIN_DIR/state/baseline-state.txt"

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

session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

window_exists() {
  local result
  result=$(tmux display-message -p -t "$1:$2" '#{window_index}' 2>/dev/null) || return 1
  [ "$result" = "$2" ]
}

if [ ! -f "$STATE_FILE" ]; then
  tmux display-message "baseline: state file not found"
  exit 1
fi

declare -a session_names=()
declare -a window_sessions=()
declare -a window_indexes=()
declare -a window_names=()
declare -a window_paths=()
declare -A session_seen=()
declare -A target_windows=()
declare -A session_has_window=()

while IFS=$'\t' read -r kind f1 f2 f3 f4 extra; do
  [ -z "$kind" ] && continue

  case "$kind" in
    '# '*)
      ;;
    '#')
      ;;
    session)
      if [ -z "$f1" ]; then
        continue
      fi
      session_name="$(unescape_field "$f1")"
      if [ -z "${session_seen[$session_name]}" ]; then
        session_seen[$session_name]=1
        session_names+=("$session_name")
      fi
      ;;
    window)
      if [ -z "$f1" ] || [ -z "$f2" ] || [ -z "$f3" ]; then
        continue
      fi

      session_name="$(unescape_field "$f1")"
      window_index="$(unescape_field "$f2")"
      window_name="$(unescape_field "$f3")"
      window_path="$(unescape_field "$f4")"

      if [ -z "${session_seen[$session_name]}" ]; then
        session_seen[$session_name]=1
        session_names+=("$session_name")
      fi

      window_sessions+=("$session_name")
      window_indexes+=("$window_index")
      window_names+=("$window_name")
      window_paths+=("$window_path")

      target_windows["$session_name:$window_index"]=1
      session_has_window["$session_name"]=1
      ;;
  esac
done < "$STATE_FILE"

if [ "${#window_sessions[@]}" -eq 0 ]; then
  tmux display-message "baseline: no windows found in state file"
  exit 1
fi

for session_name in "${session_names[@]}"; do
  if [ -z "${session_has_window[$session_name]}" ]; then
    continue
  fi

  if ! session_exists "$session_name"; then
    tmux new-session -d -s "$session_name" -n "__baseline_tmp__" >/dev/null 2>&1 || {
      tmux display-message "baseline: failed to create session '$session_name'"
      exit 1
    }
  fi
done

restored_windows=0

for i in "${!window_sessions[@]}"; do
  session_name="${window_sessions[$i]}"
  window_index="${window_indexes[$i]}"
  window_name="${window_names[$i]}"
  window_path="${window_paths[$i]}"

  if window_exists "$session_name" "$window_index"; then
    tmux rename-window -t "$session_name:$window_index" "$window_name" >/dev/null 2>&1
    if ! tmux respawn-window -k -t "$session_name:$window_index" -c "$window_path" >/dev/null 2>&1; then
      tmux respawn-window -k -t "$session_name:$window_index" >/dev/null 2>&1
    fi
  else
    if ! tmux new-window -d -t "$session_name:$window_index" -n "$window_name" -c "$window_path" >/dev/null 2>&1; then
      tmux new-window -d -t "$session_name:$window_index" -n "$window_name" >/dev/null 2>&1
    fi
  fi

  restored_windows=$((restored_windows + 1))
done

for session_name in "${session_names[@]}"; do
  if [ -z "${session_has_window[$session_name]}" ]; then
    continue
  fi

  kill_ids=()
  while IFS=$'\t' read -r existing_id existing_index; do
    [ -z "$existing_id" ] && continue
    [ -z "$existing_index" ] && continue
    if [ -z "${target_windows[$session_name:$existing_index]}" ]; then
      kill_ids+=("$existing_id")
    fi
  done < <(tmux list-windows -t "$session_name" -F '#{window_id}\t#{window_index}' 2>/dev/null)

  for existing_id in "${kill_ids[@]}"; do
    tmux kill-window -t "$existing_id" >/dev/null 2>&1
  done
done

for session_name in "${session_names[@]}"; do
  if window_exists "$session_name" "__baseline_tmp__"; then
    tmux kill-window -t "$session_name:__baseline_tmp__" >/dev/null 2>&1
  fi
done

tmux display-message "baseline: restored ${#session_names[@]} sessions and $restored_windows windows"
