# Claude PR Review Checklist

The automated review checks every PR against this list, `AGENTS.md`, and `docs/standards/*.md`. Edit this file to tune the review for this repo.

## Standards (flag with file:line)

- SOQL outside a `*Selector` class
- Business logic in triggers, trigger handlers, controllers, `@AuraEnabled` or `@InvocableMethod` methods
- A new trigger that isn't `new <Object>TriggerHandler().run();` with a handler extending `TriggerHandler`, or a second trigger on an object that already has one
- A class without a sharing keyword; `without sharing` without a justification comment
- SOQL or DML not in user mode (`WITH USER_MODE`, `insert as user`, `AccessLevel.USER_MODE`) without a documented reason
- Test data not built with `<Object>TestBuilder` / `<Object>Domain.newRecord`; no bulk (200-record) test for trigger or service logic
- Hard-coded record IDs, URLs or user names
- New metadata with an `apiVersion` other than the repo's `sourceApiVersion` (`sfdx-project.json`)
- Names that don't follow `docs/standards/naming.md`
- New or renamed files outside `force-app/` with spaces (or `&`, parentheses) in the name: should be PascalCase (AGENTS.md §7). Never flag `force-app/` metadata names
- A behavior-sensitive LWC change (bug fix, permission-gated UI, non-trivial client logic) with no Jest test, as a **Should fix**, not Blocking. Never ask for tests of implementation details
- A changed record-triggered flow with no entry criteria, or a Get/DML element without a fault path

## PR hygiene

- Every PR template section filled in: Asana link, summary, branch and manifest, manual config changes, testing
- **The manifest matches the diff.** Flag changed `force-app` components missing from `manifest/feat/<feature>.xml`, and manifest entries with no matching change
- The PR targets the base branch named in `AGENTS.md` (multi-environment repos: `feat/*` → `uat`, `hotfix/*` and `deploy/*` → `main`)

## Output rules

- Post inline comments only for concrete issues. Each one names the standard it breaks and suggests a fix.
- Post one summary comment, grouped as **Blocking** / **Should fix** / **Nits**. If nothing is found, say "No issues found against the project standards" and list what was checked.
- No praise, and don't restate the diff.
