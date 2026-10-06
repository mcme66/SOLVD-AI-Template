# API Version Policy

- **New metadata uses the repo's `sourceApiVersion`** (`sfdx-project.json`), which matches **Production's** API version. Check Production's version with `sf org display -o <client>-prod --json | jq .result.apiVersion`.
- Set `sourceApiVersion` to Production's version when the repo is created, and raise it only **after Production upgrades** to a new release, in its own PR.
- **Sandboxes can run Salesforce preview releases ahead of Production** for a few weeks before each release. Metadata created or retrieved there can carry a higher `<apiVersion>` than Production accepts. Lower it to Production's version before deploying to Production.
- Repos that opt into the multi-environment flow enforce this in CI: the "Production API version" check fails PRs into `main` with changed metadata above Production's version (`scripts/ci/check-api-version.sh`). See [`../optional/MultiEnvironment.md`](../optional/MultiEnvironment.md).
- **Experience Cloud sites** compiled on a preview version can't be edited back down in source. Deploy them using the site's "deploy via Metadata API" setting, so they recompile on Production's version.
