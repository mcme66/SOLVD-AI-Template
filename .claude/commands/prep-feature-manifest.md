# Prepare a Feature Manifest

1. Diff the branch against its base (the base branch in `AGENTS.md`, usually `main`): `git diff --name-only <base>...HEAD -- force-app`.
2. Map each changed file to its metadata type and member name. Be specific:
   - Custom fields go under `CustomField` as `Object__c.Field__c`. Include the whole object only if the object itself is new.
   - Tabs are `CustomTab`. LWC bundles are `LightningComponentBundle`. Flows are `Flow`.
   - Changes to an object's top-level `*.object-meta.xml` with no field changes: list them for the author, and don't add the whole object.
3. Write `manifest/feat/<feature>.xml`, where the feature is the branch name without the `feat/`, `fix/` or `hotfix/` prefix. Use the `sourceApiVersion` from `sfdx-project.json` as `<version>`, and no comments.
4. Validate it check-only against the author's dev sandbox (alias from `AGENTS.md`, or ask): `sf project deploy start --dry-run -o <client>-dev-<initials> -x manifest/feat/<feature>.xml --test-level RunLocalTests --wait 60`. Report any failures.
5. If new objects or fields are included, list them and ask which permission set should grant access. Prefer an existing permission set with the project's prefix (see `AGENTS.md`). Add the chosen one to the manifest.
