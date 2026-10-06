# Declarative Standards (Flows and Configuration)

## Flow or Apex?

| Use Flow when                                         | Use Apex when                                                                         |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Simple same-record field updates (a before-save flow) | Logic is complex, branches heavily, or needs to be reused                             |
| Screen flows and guided processes                     | High volume, or tight control over governor limits is needed                          |
| An admin needs to maintain it                         | The behavior needs unit tests and has to be refactored safely                         |
| Notifications and simple record creation              | It integrates with external systems or sits on the trigger path of a framework object |

If an object already has an Apex trigger handler, put new trigger-time logic in the handler, not in a new record-triggered flow, so the order of execution stays predictable.

## Record-triggered flows

- Aim for one record-triggered flow per object per timing (before-save or after-save).
- Always set entry criteria. Never run on every save.
- Every Get, Create, Update and Delete element has a **fault path** that logs or surfaces the error.
- No hard-coded IDs. Look up records by developer name, or use Custom Metadata.
- Every flow has a description, and so does each version.

## Configuration you make by hand

Changes made in the Setup UI of your dev sandbox (fields, layouts, permission sets, list views, sharing settings) don't reach the repo on their own. Before opening a PR:

1. Retrieve them into your branch: `sf project retrieve start -o <client>-dev-<initials> -m <Type>:<Name>`.
2. Add them to your feature manifest (`manifest/feat/<feature>.xml`).
3. List anything that **can't** be deployed through metadata (some Experience Cloud and org settings) in the PR's "Manual config changes" section, so the deployer can repeat it by hand.

## Permissions

- Grant access with permission sets, never by editing profiles.
- Every new object or field ships with the permission set that grants it, in the same manifest.
