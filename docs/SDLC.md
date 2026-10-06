# Software Development Lifecycle

How a change moves from a developer's sandbox to Production in a SOLVD Salesforce repo. This is the default flow. A repo can opt into the heavier [multi-environment flow](optional/MultiEnvironment.md) when it has a shared UAT sandbox and more than one team deploying.

## Quick reference

| Item                | Convention                                                                          |
| ------------------- | ----------------------------------------------------------------------------------- |
| Long-running branch | `main` (= Production)                                                               |
| Feature branch      | `feat/<asana-id>-<short-desc>` from `main`, PR into `main` (squash merge)           |
| Tooling / docs      | `chore/<short-desc>` from `main`, PR into `main`                                    |
| Feature manifest    | `manifest/feat/<feature>.xml`                                                       |
| Org aliases         | `<client>-prod`, `<client>-dev-<initials>`                                          |
| Tracker             | Asana (link the task in every PR)                                                   |
| Checks on every PR  | Static analysis (Prettier, ESLint, LWC Jest, PMD on changed Apex) and Claude review |

## The flow

1. Pick up an **Asana** task.
2. Branch from an up-to-date `main`: `git switch main && git pull && git switch -c feat/<asana-id>-<short-desc>`.
3. Build in **your dev sandbox**. Agents may deploy there freely; Production deploys are blocked for agents.
4. Retrieve anything you configured in Setup into your branch (see [`standards/declarative.md`](standards/declarative.md)).
5. Run **`/prep-pr`** in Claude Code. It builds the feature manifest, checks the standards, runs the tests, and opens a PR with every template section filled in.
6. Static analysis and the Claude review run on the PR. Address what they find.
7. Get a review. Approvals aren't required by default; a repo can [require them](optional/RequiredApprovals.md).
8. A person deploys to Production from the feature manifest, validating first (`sf project deploy validate -o <client>-prod -x manifest/feat/<feature>.xml --test-level RunLocalTests`), then quick-deploying the validated job.
9. Merge the PR after the deploy succeeds, so `main` matches Production. Then delete the branch locally and on GitHub.

## Keeping `main` close to Production

Production changes outside git: admins edit configuration, packages upgrade, and Salesforce releases three times a year. Refresh `main` from Production regularly, and always after a deploy, with `/refresh-metadata main`. It runs the full retrieve on a `refresh/` branch and opens a PR, so drift shows up as a reviewable diff.

## When to opt into more process

| Situation                                                     | Opt-in                                                 |
| ------------------------------------------------------------- | ------------------------------------------------------ |
| A shared UAT sandbox, client testers, scheduled releases      | [Multi-environment flow](optional/MultiEnvironment.md) |
| Several developers, or a client that wants sign-off on merges | [Required approvals](optional/RequiredApprovals.md)    |
| You want agents to track sub-tasks locally between sessions   | [Beads](optional/Beads.md)                             |
