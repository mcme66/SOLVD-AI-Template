# Opt-in: Beads for Agent Task Lists

[beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`) gives agents a local, git-synced task list that survives between sessions. It's useful on long builds where an agent works through many small steps. **Asana stays the source of truth** for the client and the team; beads only tracks an agent's own sub-tasks.

## Turning it on

1. Install `br` (see its README), then run `br init` in the repo and commit `.beads/`.
2. List beads under **Opt-ins enabled** in the **Project** section of `AGENTS.md`, and add this to that section:

   > This repo uses beads (`br`) for agent sub-tasks. Run `br ready` at the start of a session, `br update <id> --status=in_progress` when you start a task, `br close <id>` when you're done, and `br sync --flush-only` before committing. `br robot-docs` prints more usage. Never run bare `bv` (it opens an interactive TUI); use `bv --robot-*` flags only. Link each bead to its Asana task ID.

3. Add `"Bash(br *)"` to `permissions.allow` in `.claude/settings.json`.
