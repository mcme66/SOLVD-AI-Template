# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor and others) and the people directing them. `CLAUDE.md` imports this file. **Everything here is mandatory.**

## Project

<!-- Fill this in when you create the repo from the template, and keep it current. Agents read it for orgs, people and the tracker. -->

- **Client and org:** `<Client name>` Salesforce org (`<edition>`)
- **Asana project:** `<link>`
- **SOLVD lead:** `<name>` (`@<github-handle>`)
- **Org aliases:** `<client>-prod` (Production), `<client>-dev-<initials>` (each developer's sandbox)
- **Base branch:** `main` (= Production)
- **Permission set prefix:** `<PREFIX>_` (see [`docs/standards/naming.md`](docs/standards/naming.md))
- **Opt-ins enabled:** none <!-- any of: multi-environment flow, required approvals, beads. See docs/optional/ -->

Add project context below as you learn it: architecture, integrations, managed packages, gotchas.

<!-- solvd-sdlc-v2: managed by SOLVD. Edit the source in SOLVD-cloud/base-sfdc-template, not per repo. -->

## 1. What the repo is for

**The Salesforce org is the source of truth, not git.** Production changes in ways that never pass through this repo (admin configuration, managed packages, release upgrades). Git and GitHub are how we review changes and record what was built and why. Expect drift, and refresh from the org rather than assuming the repo is complete.

`client-context/` holds the SOW, scoping notes and meeting transcripts. Read it before planning work, so what you build matches what SOLVD promised to deliver.

## 2. Read first

- [`docs/SDLC.md`](docs/SDLC.md): how work moves from a dev sandbox to Production
- [`docs/standards/`](docs/standards/): Apex, naming, LWC, declarative, API version
- `client-context/`: scope, decisions and stakeholders

## 3. Branching rules

- `main` tracks Production. It is protected by the SOLVD-cloud org ruleset: every change lands through a PR, and force-pushes and deletion are blocked. Never commit to `main` directly or try to get around a rejected push (changing remotes, rewriting history, disabling hooks). If a push to `main` is rejected, move the commits to a branch (`git switch -c <branch>`, then `git branch -f main origin/main`) and open a PR.
- **Features** branch from the base branch as `feat/<asana-id>-<short-desc>`; fixes as `fix/<asana-id>-<short-desc>`. **Tooling and docs-only changes** (no `force-app/`, no manifest) use `chore/<short-desc>`. If there's no Asana task, ask the user for one before inventing a name.
- Commit in small, descriptive commits. Push with `git push -u origin HEAD`.
- **Agents never merge PRs** unless the user explicitly tells them to.
- After your PR is merged, delete the local branch and pull the base branch: `git switch main && git pull && git branch -D <branch>`. Use `-D`, because squash merges aren't recognized by `-d`.
- Repos that opt into the multi-environment flow (`main` = Production, `uat` = UAT sandbox) follow [`docs/optional/MultiEnvironment.md`](docs/optional/MultiEnvironment.md) instead of the base-branch rules above.

## 4. Every PR must

1. Link its **Asana task**.
2. Include a **feature manifest** at `manifest/feat/<feature>.xml` listing every changed `force-app/` component.
3. List any **configuration made by hand in the org** that isn't in source.
4. Describe the **testing** done and which org it was done in.

Use `/prep-pr`. It builds the manifest, checks the standards, runs the tests, and fills in `.github/pull_request_template.md`.

## 5. Coding rules (summary of [`docs/standards/apex.md`](docs/standards/apex.md))

- **New triggers** contain only `new <Object>TriggerHandler().run();`, with one trigger per object, and the handler `extends TriggerHandler` (the vendored kevinohara80 framework).
- **SOQL goes only in `<Object>Selector` classes**, `WITH USER_MODE`.
- **Record logic and record creation defaults** live in `<Object>Domain` (`newRecord(...)`). **Business processes and DML** live in `<Area>Service`.
- **Controllers, `@AuraEnabled`, `@InvocableMethod` methods and handlers only delegate.** No queries or business logic in them.
- **Test data** comes from `<Object>TestBuilder` (`@IsTest`), built on Domain defaults. There is no shared `TestDataFactory`.
- **Legacy code migrates when touched.** Don't refactor unrelated code in a feature PR. New metadata uses the repo's `sourceApiVersion`.

## 6. Salesforce CLI rules

- **Deploy freely to non-production orgs:** sandboxes, scratch orgs and Developer Edition orgs. Check-only validation is fine against any org (`sf project deploy validate`, `sf project deploy start --dry-run`).
- **Production deploys are blocked for agents** by the deploy guard in the `solvd-salesforce-development` plugin, which this repo enables in `.claude/settings.json`. It checks the target org live; if it can't tell what the target is, it asks the user. Don't try to get around it. A person runs Production deploys.
- **Always pass `-o <alias>` explicitly** on deploys and retrievals.
- **If you deploy something to an org, commit the same change on your branch** and open a PR in the same session, so the repo doesn't drift from the org.
- Anonymous Apex and data changes (`sf apex run`, `sf data create|update|upsert|delete|import`) always ask the user first. Run them only when the user asked for that change.
- Retrieve what you changed in the org: `sf project retrieve start -o <alias> -x manifest/feat/<feature>.xml`.
- Org XML is never reformatted: `.prettierignore` excludes `force-app/**/*.xml`, because Prettier corrupts formulas and validation rules. Apex and LWC are formatted on commit.

## 7. File naming (outside `force-app/`)

- **No spaces in file or folder names.** Name new docs, diagrams, scripts and other repo files in PascalCase, for example `SystemArchitecture.md`. No spaces, `&`, parentheses, or `(2)`-style copy suffixes. `client-context/` is the exception: keep client documents under the names they arrived with.
- **Never rename anything under `force-app/`.** Metadata file names come from Salesforce API names, and renaming them breaks deploys.

## 8. Tracking

**Asana** is SOLVD's project tracker. Reference the Asana task ID in branch names and PRs, and read the task before starting work. Don't introduce another tracker unless the repo has opted into beads for agent task lists ([`docs/optional/Beads.md`](docs/optional/Beads.md)); even then, Asana stays the source of truth for the client.

<!-- end-solvd-sdlc-v2 -->
