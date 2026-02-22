#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

baseline_key="$(tmux show-option -gqv "@baseline_key")"
if [ -z "$baseline_key" ]; then
  baseline_key="b"
fi

tmux bind-key "$baseline_key" run-shell "$CURRENT_DIR/scripts/menu.sh"
