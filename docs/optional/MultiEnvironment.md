# Opt-in: Multi-Environment Flow

Use this when the repo has a shared UAT sandbox, client testers, and scheduled Production releases. It is the flow SOLVD runs on its largest multi-team engagement. Most repos don't need it.

## The model

| Item                  | Convention                                                                                                                    |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Long-running branches | `main` (= Production), `uat` (= UAT sandbox). `uat` is the repo's default branch                                              |
| Feature branch        | `feat/<asana-id>-<short-desc>` from `uat`, PR into `uat` (squash merge)                                                       |
| Tooling / docs branch | `chore/<short-desc>` from `uat`, PR into `uat`                                                                                |
| Hotfix branch         | `hotfix/<asana-id>-<short-desc>` from `main`, PR into `main`; then cherry-pick its squash commit onto a new branch from `uat` |
| Deployment branch     | `deploy/YYYY-MM-DD-<name>` from a freshly refreshed `main`, PR into `main` (merge commit). Built with `/prep-deploy-branch`   |
| Refresh branch        | `refresh/<uat\|main>-YYYYMMDD`, created by `/refresh-metadata`                                                                |
| Deployment manifest   | `manifest/deploy/YYYY-MM-DD-<name>.xml`                                                                                       |
| Org aliases           | `<client>-prod`, `<client>-uat`, `<client>-rehearsal`, `<client>-dev-<initials>`                                              |

1. Features are built in dev sandboxes and PR'd into `uat`. Before merging, a deployer deploys the PR's feature manifest to the UAT sandbox; the PR merges once that deploy succeeds. Run `/refresh-metadata uat` afterwards.
2. For a release, refresh `main` from Production, then run `/prep-deploy-branch <name> <PR numbers>`. It cherry-picks the selected `uat` PRs onto a `deploy/` branch, combines their manifests, lowers API versions to Production's, and validates against Production.
3. A deployer rehearses in a fresh sandbox on Production's API version, deploys to Production, merges the `deploy/` PR, and runs `/refresh-metadata main`.
4. Hotfixes branch from `main`. After the merge, cherry-pick the squash commit onto a new branch from `uat` (`git switch -c hotfix/<id>-to-uat origin/uat && git cherry-pick -x <sha>`). Never PR the hotfix branch itself into `uat`: it would carry Production-state files over newer UAT work.
5. Tooling (`.github/`, `.claude/`, `AGENTS.md`, `docs/`, `scripts/`) lands in `uat` first and reaches `main` with each `deploy/` branch.

## Turning it on

1. Create `uat` from `main`, push it, and make it the default branch (**Settings → General → Default branch**).
2. Add rulesets for `main` and `uat` (**Settings → Rules → Rulesets**): block deletion and force-push, require a PR, and require the status checks "Lint, format & unit tests" and "Apex static analysis (PMD)" (plus "Production API version" on `main`). Add required approvals if the repo wants them ([`RequiredApprovals.md`](RequiredApprovals.md)).
3. Add `uat` to `on.pull_request.branches` in `.github/workflows/static-analysis.yml` and `claude-code-review.yml`. Turn on the Production API version check by setting the `PROD_API_VERSION` repo variable to Production's version: `gh variable set PROD_API_VERSION -R SOLVD-cloud/<repo> --body 67.0`.
4. In `AGENTS.md`, set **Base branch** to `uat`, list the multi-environment flow under **Opt-ins enabled**, and name the deployers. Update `.claude/commands/prime.md` to diff against `uat`.
5. Say in the **Project** section who may create `deploy/` and `refresh/` branches (normally only the named deployers).
