# Setting Up the Claude PR Review

The template ships two GitHub Actions workflows that run Claude Code:

- `.github/workflows/claude-code-review.yml` reviews every PR against `AGENTS.md`, `docs/standards/` and [`.github/claude-review-checklist.md`](../../.github/claude-review-checklist.md), then posts inline comments and one summary comment.
- `.github/workflows/claude.yml` answers `@claude` mentions in PR and issue comments from SOLVD-cloud org members.

Both need a `CLAUDE_CODE_OAUTH_TOKEN` repository secret. Until it's set they **skip with a notice** rather than fail, so a new repo's checks stay green. Set it up once per repo:

1. **Install the Claude GitHub App** on the repo. In Claude Code, from the repo directory, run `/install-github-app` and follow the prompts. It installs the app, can create the token and secret for you, and opens a PR with its own workflow files. **Close that PR without merging**, because the template already has the workflows. Alternatively, a SOLVD-cloud org owner can install [github.com/apps/claude](https://github.com/apps/claude) and grant it the repo.
2. **Create the token** (skip if `/install-github-app` already did): run `claude setup-token` in a terminal and copy the token it prints. It's tied to the Claude subscription of whoever runs it, so use the account the team has agreed on, not a personal one.
3. **Add the secret:** `gh secret set CLAUDE_CODE_OAUTH_TOKEN -R SOLVD-cloud/<repo>` and paste the token, or use **Settings → Secrets and variables → Actions → New repository secret**.
4. **Check it works:** open a small PR. The "Claude Code Review" job should post a summary comment within a few minutes. If it doesn't, open the job log; `show_full_output: true` prints the whole session.

## Tuning the review

Edit [`.github/claude-review-checklist.md`](../../.github/claude-review-checklist.md) to change what the review flags. It's plain markdown, and the workflow reads it on every run. Keep repo-specific rules there or in `docs/standards/`, not in the workflow file.

The review and the changed-file style checks skip `refresh/` PRs opened by the maintainers listed in the `TRUSTED_REFRESH_AUTHORS` variable, because refresh PRs carry org metadata as-is. Set it as a JSON array of GitHub logins, for the whole org or per repo: `gh variable set TRUSTED_REFRESH_AUTHORS -R SOLVD-cloud/<repo> --body '["login1","login2"]'`. When it's unset, every PR gets the full checks.
