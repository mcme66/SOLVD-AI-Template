## Asana task

<!-- link -->

## Summary

<!-- what changed and why -->

## Branch & manifest

- Branch: `<feat/...>`
- Manifest: `manifest/feat/<feature>.xml`

## Manual config changes made in the org

<!-- anything done by hand in Setup that isn't in source; "None" if none -->

## Testing

- Org: `<client>-dev-<initials>`
- What was tested:

## Checklist

- [ ] New triggers use `TriggerHandler`; SOQL only in selectors; logic in domain/service (`docs/standards/apex.md`)
- [ ] Tests use `*TestBuilder`; bulk case covered
- [ ] New metadata at the repo's `sourceApiVersion`
- [ ] Manifest covers every changed component
