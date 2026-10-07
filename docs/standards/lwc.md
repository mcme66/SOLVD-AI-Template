# Lightning Web Component Standards

## Data access

- Reads go through `@AuraEnabled(cacheable=true)` methods on a controller that delegates to a **Service** (see [`apex.md`](./apex.md)). Writes are imperative Apex calls.
- For single-record CRUD, prefer the `lightning/ui*Api` adapters (`getRecord`, `updateRecord`) and Lightning Data Service. They respect field-level security and share a cache.
- After a write, refresh wired data with `refreshApex` or `notifyRecordUpdateAvailable`.

## Component design

- One responsibility per component. Compose smaller components rather than growing one.
- Public API is `@api` properties and methods only. Child-to-parent communication uses `CustomEvent`, with lowercase event names and no hyphens.
- No `@track` on primitives. Reactivity on fields is automatic.
- No direct DOM manipulation outside `this.template.querySelector` in `renderedCallback`, and guard it so it runs once.
- User-facing text comes from Custom Labels (`@salesforce/label/c.<Label>`).

## Errors and feedback

- Show errors with `lightning/platformShowToastEvent`, or an inline error panel for in-form problems.
- Never swallow a rejected promise. Log the error and show something to the user.

## Accessibility

- Every input has a visible label (or `label-hidden` with `label` set).
- Interactive elements are reachable by keyboard. Use base components (`lightning-button`, `lightning-input`) rather than clickable `div`s.

## Tests (when they protect behavior)

Jest tests are **not required for every component**. Write one when it protects behavior a user or reviewer would notice if it broke, for example:

- a regression you just fixed
- permission-dependent UI (an action hidden when the user lacks access)
- non-trivial client-side logic (calculations, validation, state transitions)

Test what the user sees and does, not implementation details such as private method calls or internal property values. Tests live in `__tests__/<component>.test.js` and run with `npm test` in CI. Shared stubs live in `force-app/test/jest-mocks/`.
