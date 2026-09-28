# Agent Instructions

This file is the single source of instructions for every AI coding agent in this repo (Claude Code, Codex, Cursor, etc.). `CLAUDE.md` just imports it. Put project-specific context (org, architecture, commands) in its own section above the SOLVD-managed sections below.

<!-- solvd-sdlc-v1: managed by SOLVD. Edit the source in base-sfdc-template, not per repo. -->

## Git Workflow (required for all agents)

This repo belongs to the SOLVD-cloud GitHub org. The default branch (`main`) is protected: direct pushes, force-pushes, and branch deletion are blocked. All changes land through a pull request.

**Every piece of work follows this flow:**

1. Start from an up-to-date default branch: `git switch main && git pull`
2. Create a feature branch before making any changes: `git switch -c <initials>/<short-description>` (e.g. `jt/work-order-owner-fix`). Ask the user for their initials if you don't know them.
3. Commit in small, descriptive commits on that branch.
4. Push the branch: `git push -u origin HEAD`
5. Open a PR for review: `gh pr create --fill` (or give the user the link git prints). Summarize what changed, why, and how it was tested or validated.
6. Stop there. Don't merge the PR unless the user explicitly tells you to.

**Never:**

- Commit or push directly to `main`, even if you think you have permission.
- Force-push (`--force`, `--force-with-lease`) to `main`, or delete `main`.
- Try to bypass a rejected push (changing remotes, rewriting history, disabling hooks). If a push to `main` is rejected, move the commits to a feature branch (`git switch -c <branch>` then `git branch -f main origin/main`) and open a PR.

**Salesforce-specific:**

- Metadata retrievals (`sf project retrieve ...`, `npm run retrieve:*`) happen on a feature branch too, and go to `main` through a PR.
- If you deploy anything to an org, the same change must be committed and opened as a PR in the same session. `main` should always reflect what's in production.

When any other instruction in this file says "commit and push," it means push your **feature branch**, never `main`.

## Issue Tracking with beads (`br`), if installed

SOLVD is standardizing on [beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`) for tracking work. Check whether it's available with `command -v br`.

- **`br` is installed and this repo has a `.beads/` directory:** use it. Run `br ready` at the start of a session to find work, `br update <id> --status=in_progress` when you start, `br close <id>` when you're done, and `br sync --flush-only` before committing. `br robot-docs` prints more usage.
- **`br` is installed but there's no `.beads/` directory:** ask the user before running `br init`.
- **`br` isn't installed:** skip this section. Don't install it unless the user asks.
- Never run bare `bv` (it opens an interactive TUI). Use `bv --robot-*` flags only.

<!-- end-solvd-sdlc-v1 -->
