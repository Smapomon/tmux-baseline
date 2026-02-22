#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux display-menu -T "baseline" \
  "save" s "run-shell '$CURRENT_DIR/save.sh'" \
  "restore" r "run-shell '$CURRENT_DIR/restore.sh'" \
  "safe restore" g "run-shell '$CURRENT_DIR/safe_restore.sh'" \
  "status" v "run-shell '$CURRENT_DIR/status.sh'" \
  "exit" q ""
