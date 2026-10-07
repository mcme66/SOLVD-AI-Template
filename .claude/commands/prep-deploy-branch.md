# Prepare a Production Deployment Branch

**Multi-environment repos only** (see `docs/optional/MultiEnvironment.md`), and only for the deployers named in `AGENTS.md`. Arguments: $ARGUMENTS = a deployment name, then the numbers of the PRs (already merged into `uat`) to ship.

1. Confirm `main` was refreshed from Production recently: `git log -1 --format=%cd origin/main`. If it's older than the last Production change, run `/refresh-metadata main` first and merge that PR.
2. `git switch main && git pull && git switch -c deploy/$(date +%F)-<name>`.
3. For each PR: run `gh pr view <n> --json title,headRefName,mergeCommit,files`, then `git cherry-pick -x <mergeCommit sha>`. Resolve conflicts **hunk by hunk**, keeping only that PR's changes. Never take the whole `uat` version of a file, because shared files carry other, unreleased features. **Stop and ask a deployer** whenever a profile, permission set, permission set group, `*.object-meta.xml`, layout or flexipage conflicts.
4. Sync tooling from `uat`, so `main` keeps CI and the AI docs current: `git checkout origin/uat -- .github .claude AGENTS.md CLAUDE.md README.md docs scripts package.json package-lock.json`. Commit it as "Sync tooling from uat".
5. Combine the PRs' `manifest/feat/*.xml` files into `manifest/deploy/<date>-<name>.xml`, removing duplicates.
6. Lower any `<apiVersion>` above Production's (the `PROD_API_VERSION` repo variable, or `sourceApiVersion`) in the included files, and list each change.
7. Validate check-only against Production: `sf project deploy validate -o <client>-prod -x manifest/deploy/<file> --test-level RunLocalTests --wait 60`. Report the validation job ID.
8. Push and open a PR against `main`. List the included PRs, the manifest, the validation ID and any API-version edits, and add the contributing PR authors as reviewers.

The rehearsal deploy, the real Production deploy (a quick deploy of the validated job), the merge, and the post-deploy `/refresh-metadata main` are done by a deployer, not by you. The deploy guard blocks agents from Production deploys.
