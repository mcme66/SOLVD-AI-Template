# Opt-in: Required Approvals

By default the SOLVD-cloud org ruleset ("Baseline: default branch requires PR") makes every change land through a PR but needs **no approvals**, so a consultant working alone can merge their own PRs after the checks pass. Turn on approvals when several developers share the repo, or when the client wants sign-off before anything merges.

1. **Settings → Rules → Rulesets → New branch ruleset.** Target the default branch (and `uat` too, if the repo uses the [multi-environment flow](MultiEnvironment.md)).
2. Enable **Require a pull request before merging** with **Required approvals: 1**, and turn on **Dismiss stale pull request approvals when new commits are pushed**.
3. Optionally enable **Require status checks to pass** and add "Lint, format & unit tests" and "Apex static analysis (PMD)" (they appear after the first PR runs them).
4. Add the people or team allowed to bypass, if any, under **Bypass list**.
5. Name the reviewers in the **Project** section of `AGENTS.md` and add `--reviewer <handles>` to the `gh pr create` step in `.claude/commands/prep-pr.md`.

SOLVD doesn't use `CODEOWNERS` by default. Name reviewers in `AGENTS.md` and request them on the PR instead.
