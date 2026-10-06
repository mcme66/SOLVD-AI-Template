# Prepare a Pull Request

Arguments: $ARGUMENTS (optional: the Asana task URL)

1. Work out the base branch from `AGENTS.md` (usually `main`; in multi-environment repos `main` for `hotfix/*` and `uat` otherwise). Run `git diff --name-only <base>...HEAD` and read the changed files.
2. If `force-app/` changed and `manifest/feat/<feature>.xml` is missing or doesn't match the diff, run `/prep-feature-manifest` first.
3. Check the diff against `docs/standards/*.md`: the trigger framework, selector/domain/service layering, test builders, sharing and user mode, API version, and naming. Fix any violations before continuing, or explain to the author why one stays.
4. Run `npm run lint` and `npm test`, plus `npx prettier --check` on changed non-XML files. Fix any failures.
5. Ask the author which org they tested in, what they tested, and whether they made any configuration changes by hand in the org. Retrieve any deployable configuration into the branch and add it to the manifest.
6. If there's no Asana task link yet, ask for it. Write the PR body from `.github/pull_request_template.md`, with every section filled in, including the branch name and manifest path.
7. Push the branch and open the PR: `gh pr create --base <base> --title "<Asana id>: <summary>" --body-file <tmp file>`. If `AGENTS.md` names required reviewers, add `--reviewer <handles>`.

Never merge the PR.
