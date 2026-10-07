# SOLVD Salesforce Project Base Template

> Built with ❤️&nbsp; by John

The starting point for every SOLVD Salesforce client repo. It sets up the SFDX project, formatting and linting, full-org metadata retrieval, GitHub checks and a Claude PR review, and the Claude Code configuration SOLVD consultants and their agents work from. The standards and workflow come from SOLVD's largest multi-team engagement, scaled down to fit a typical project.

## Create a repo from this template

```bash
gh repo create SOLVD-cloud/<client> --private --template SOLVD-cloud/base-sfdc-template --clone
cd <client>
```

Then, on a branch (`chore/initial-setup`), work through this checklist and open a PR:

1. **Name it.** Set `name` in `package.json` and `sfdx-project.json` to the repo name, and change this README's title and intro to describe the client's org.
2. **Fill in the Project section of [`AGENTS.md`](AGENTS.md):** client, Asana project, SOLVD lead, org aliases, permission set prefix. Agents read it on every session.
3. **Match Production's API version.** Set `sourceApiVersion` in `sfdx-project.json` to Production's version (`sf org display -o <client>-prod --json | jq .result.apiVersion`).
4. **Retrieve the baseline** from Production into `force-app/` (see [Metadata retrieval](#metadata-retrieval)), then fill in "Where existing classes map" in [`docs/standards/apex.md`](docs/standards/apex.md).
5. **Add client context:** put the SOW, scoping notes and call transcripts in `client-context/`. Running `/asana-init` turns them into a proposed Asana board.
6. **Turn on the Claude review:** follow [`docs/setup/ClaudeCodeReview.md`](docs/setup/ClaudeCodeReview.md). Until the token is set, the Claude workflows skip without failing.
7. **Choose opt-ins** if the engagement needs them: the [multi-environment flow](docs/optional/MultiEnvironment.md), [required approvals](docs/optional/RequiredApprovals.md), or [beads](docs/optional/Beads.md).

The SOLVD-cloud org ruleset already protects `main`: every change goes through a PR, and force-pushes and deletion are blocked.

## Prerequisites

- [Node.js](https://nodejs.org/) via [nvm](https://github.com/nvm-sh/nvm), using the version in `.nvmrc`
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`), plus `jq`
- VS Code with the extensions recommended in `.vscode/extensions.json`
- [Claude Code](https://claude.com/claude-code). It reads [`AGENTS.md`](AGENTS.md) automatically.

## Setup

```bash
git clone git@github.com:SOLVD-cloud/<repo>.git
cd <repo>
nvm use
npm ci
sf org login web -a <client>-dev-<initials> -r https://test.salesforce.com
sf config set target-org=<client>-dev-<initials>
```

The first time you start Claude Code in the repo and trust the folder, it registers SOLVD's plugin marketplace and enables the `solvd-salesforce-development` plugin (see `.claude/settings.json`). The plugin brings the Apex/LWC standards skill, the trigger scaffold, test-writing agents, and the **org guard**: agents can deploy, run anonymous Apex and write data freely in sandboxes, scratch orgs and Developer Edition orgs. In Production, deploys are blocked and anonymous Apex and data writes need your approval each time.

## How work flows

See [`docs/SDLC.md`](docs/SDLC.md). In short: branch from `main` as `feat/<asana-id>-<short-desc>`, build in your dev sandbox, run `/prep-pr`, let the checks and the Claude review run, and merge after a person deploys to Production.

## Claude Code commands

| Command                  | Use it to                                                           |
| ------------------------ | ------------------------------------------------------------------- |
| `/prime`                 | Load project context at the start of a session                      |
| `/prep-feature-manifest` | Build `manifest/feat/<feature>.xml` from your branch's changes      |
| `/prep-pr`               | Check standards, run tests, and open a PR with the template filled  |
| `/refresh-metadata`      | Refresh `main` from Production on a `refresh/` branch and open a PR |
| `/org-review`            | Document an org's metadata with parallel subagents                  |
| `/asana-init`            | Propose an Asana board from `client-context/`                       |
| `/knowledge-transferer`  | Summarize the sales-to-delivery handoff from `client-context/`      |
| `/prd`                   | Build a feature step by step from a PRD                             |
| `/prep-testing-plan`     | Write a browser testing plan from a PRD                             |
| `/agent-testing`         | Run a testing plan with browser subagents                           |
| `/prep-deploy-branch`    | Multi-environment repos only: build a Production `deploy/` branch   |

## Scripts

| Command                           | What it does                                                               |
| --------------------------------- | -------------------------------------------------------------------------- |
| `npm test`                        | LWC Jest unit tests                                                        |
| `npm run lint`                    | ESLint for LWC and Aura JavaScript                                         |
| `npm run prettier:verify`         | Prettier check (org XML is intentionally excluded)                         |
| `npm run retrieve:all`            | Full metadata retrieve from an org (`-- -o <alias>`)                       |
| `npm run diff`                    | Delta manifest between two git refs (needs the sfdx-git-delta plugin)      |
| `npm run build`, `npm run deploy` | Convert a manifest to a Metadata API zip, then validate or quick-deploy it |

## Metadata retrieval

Run the retrieve in a terminal outside VS Code; the VS Code terminal can't keep up with its output.

```bash
npm run retrieve:all -- -o <client>-prod -a <api-version>
```

It discovers every metadata type, retrieves in chunks with retries, handles installed packages, removes managed-package placeholder content, and writes logs to `logs/`. Details: [`scripts/shell/README-retrieve-metadata.md`](scripts/shell/README-retrieve-metadata.md).

## Docs

- [`AGENTS.md`](AGENTS.md): the rules for people and agents in this repo
- [`docs/SDLC.md`](docs/SDLC.md): branching, review and deployment
- [`docs/standards/`](docs/standards/): Apex, naming, LWC, declarative, API version
- [`docs/setup/ClaudeCodeReview.md`](docs/setup/ClaudeCodeReview.md): turning on the Claude PR review
- [`docs/optional/`](docs/optional/): opt-in process for larger engagements

## Updating the template

The block between the `solvd-sdlc-v2` markers in `AGENTS.md`, and the files under `.claude/`, `.github/` and `docs/standards/`, are maintained here. Improve them in this repo first, then carry the change into client repos. Shared skills, agents and hooks belong in the [SOLVD plugin marketplace](https://github.com/SOLVD-cloud/solvd-claude-plugins), which updates every repo automatically.
