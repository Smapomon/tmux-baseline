# tmux-baseline

`Baseline` is a tmux plugin for creating baseline session configurations.
It's not a session manager.

Baseline is for when you don't need a full blown session manager, but want some state storage for you sessions.
Baseline will save your sessions with names, their windows, and paths. You can use it to restore to that **baseline** later on.

## Status

This is a work-in-progress personal project.

- It is not maintained as a general-purpose plugin for others.
- Expect frequent changes while ideas are tested.
- Backward compatibility is not guaranteed.

## Installation

Add this to your configuration file `~/.config/tmux/tmux.conf` || `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'Smapomon/tmux-baseline'
run '~/.tmux/plugins/tpm/tpm'
```

Reload tmux config, then press `prefix + I` to install.

## Usage

Default keybinding: `prefix + b`

Pressing it opens a picker with:

- `save`
- `restore`
- `safe restore`
- `exit`

`save` writes a readable state file to `state/baseline-state.txt` inside the plugin directory.

`restore` reads that file and applies it to tmux sessions/windows.

Note: current `restore` behavior is aggressive. It can recreate window processes and remove extra windows in sessions included in the saved state.

## Options

```tmux
# Optional: override key (default is b)
set -g @baseline_key 'b'
```

## Development

For local testing (without installing through TPM):

1. Open a tmux session.
2. From this repo root, load the plugin file:

```bash
./baseline.tmux
```

3. In tmux, press `prefix + b` to open the menu.

After you change plugin files, run `./baseline.tmux` again to reload the key binding.
