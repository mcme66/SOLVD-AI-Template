# Refresh a Long-Running Branch from Its Org

Arguments: $ARGUMENTS = the branch to refresh: `main` (default), or `uat` in multi-environment repos.

1. Map the branch to its org alias from `AGENTS.md`: `main` → `<client>-prod`, `uat` → `<client>-uat`. If the alias isn't recorded, ask.
2. `git switch <target> && git pull && git switch -c refresh/<target>-$(date +%Y%m%d)`.
3. `./scripts/shell/retrieve-all-metadata.sh -o <org> -a <sourceApiVersion from sfdx-project.json> -w 120`.
4. `git add force-app && git commit --no-verify -m "Refresh <target> from <org>"`. Stage only `force-app/`, because the retrieve script runs Prettier across the repo and can touch unrelated files (then run `git checkout -- .` to drop those). Hooks are skipped because the script has already formatted Apex and LWC, and org XML stays exactly as the org returns it.
5. Summarize `git diff --stat <target>...HEAD` by metadata type, and flag surprises: deleted classes, large profile or permission churn, or `apiVersion` above Production's on `main`.
6. Push and open a PR against `<target>` titled "Refresh <target> from <org> (<date>)". Never merge it.
