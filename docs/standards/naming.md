# Naming Conventions

Apply these to **new** metadata. Don't rename existing metadata just to match: renames break references, reports, integrations and deploys. Where a name below matches an existing class, that class is legacy and adopts the pattern when it's touched.

## Apex

| Kind                            | Pattern                                                        | Example                        |
| ------------------------------- | -------------------------------------------------------------- | ------------------------------ |
| Trigger                         | `<Object>Trigger`                                              | `WorkOrderTrigger`             |
| Trigger handler                 | `<Object>TriggerHandler`                                       | `WorkOrderTriggerHandler`      |
| Domain                          | `<Object>Domain`                                               | `WorkOrderDomain`              |
| Selector                        | `<Object>Selector`                                             | `WorkOrderSelector`            |
| Service                         | `<Area>Service`                                                | `BillingService`               |
| Controller                      | `<Feature>Controller`                                          | `WorkOrderSchedulerController` |
| Test class                      | `<ClassUnderTest>Test`                                         | `WorkOrderServiceTest`         |
| Test builder                    | `<Object>TestBuilder`                                          | `WorkOrderTestBuilder`         |
| Exception                       | `<Area>Exception`                                              | `BillingException`             |
| Batch / Queueable / Schedulable | `<Purpose>Batch` / `<Purpose>Queueable` / `<Purpose>Scheduler` | `InvoiceReminderScheduler`     |

When the object is custom, drop `__c` and underscores: `Pricing_Matrix__c` becomes `PricingMatrixSelector`.

## Declarative metadata

| Kind                 | Pattern                                                                               | Example                         |
| -------------------- | ------------------------------------------------------------------------------------- | ------------------------------- |
| Custom object        | `Title_Snake_Case__c`, singular                                                       | `Billing_Schedule__c`           |
| Custom field         | `Title_Snake_Case__c`; label matches the API name; description and help text required | `Target_Date__c`                |
| Flow                 | `<Object>_<Trigger\|Screen\|Scheduled\|Autolaunched>_<Purpose>`                       | `WorkOrder_Trigger_SetDueDates` |
| Permission set       | `<Prefix>_<Persona>_<Capability>`                                                     | `ACME_Billing_InvoiceManager`   |
| Permission set group | `<Prefix>_<Persona>`                                                                  | `ACME_Billing`                  |
| Custom Metadata type | `<Purpose>__mdt`                                                                      | `Billing_Rate__mdt`             |
| Custom Label         | `<Area>_<Message>`                                                                    | `Portal_UploadTooLarge`         |
| Validation rule      | `<Purpose>` in PascalCase with underscores                                            | `Amount_Required_When_Won`      |

## LWC

Use camelCase and a descriptive name: `workOrderScheduler`, `invoiceLineEditor`. No abbreviations and no `c` prefix in folder names.

Agree the permission set `<Prefix>` with the client at the start of the engagement and record it in `AGENTS.md`.

## Git, manifests and orgs

| Kind             | Pattern                                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------------------- |
| Feature branch   | `feat/<asana-id>-<short-desc>`                                                                              |
| Fix branch       | `fix/<asana-id>-<short-desc>`                                                                               |
| Tooling or docs  | `chore/<short-desc>`                                                                                        |
| Feature manifest | `manifest/feat/<feature>.xml`                                                                               |
| Org aliases      | `<client>-prod`, `<client>-dev-<initials>` (and `<client>-uat` if the repo uses the multi-environment flow) |

Repos that opt into the multi-environment flow add `hotfix/`, `deploy/` and `refresh/` branches (see [`../optional/MultiEnvironment.md`](../optional/MultiEnvironment.md)).
