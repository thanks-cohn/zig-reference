# Reference Archetypes

These archetypes are recurring shapes for systems code. They are not syntax rules. They are promises that make unfamiliar code easier to inspect.

## Owned resource

A type that owns memory or another resource must make these facts easy to answer:

1. What does it own?
2. Which operation releases that ownership?
3. Which operations may invalidate references into it?
4. What remains valid when an operation fails?

Construction and destruction should appear as a recognizable pair.

## Borrowed view

A borrowed view does not own the storage it refers to. Its validity depends on the owner remaining alive and on the owner not performing an invalidating mutation.

Borrowed and owned representations should use distinct types when confusing them would be dangerous.

## Checked size

Any size, capacity, offset, or allocation amount derived from runtime input must use checked arithmetic. Values that are individually valid can still overflow when added or multiplied.

## Failure-atomic mutation

An operation is failure-atomic when it either succeeds completely or leaves caller-visible state unchanged and valid.

For a growing container, allocation must succeed before the container replaces its old allocation or changes its logical length.

## Explicit invalidation

APIs and documentation must state when pointers, slices, iterators, handles, or indexes become invalid.

An implementation should never rely on the reader already knowing the invalidation behavior of a similar container.

## Stated invariants

Important types should document the conditions that must always be true. Tests should exercise those conditions after both successful and failed operations.

## Resource limits

Software that accepts uncontrolled input should make limits explicit: maximum capacity, record count, nesting depth, allocation size, or queued work.

## Canonical type order

Complex public types should generally present their contents in this order:

1. Associated public types
2. Error sets
3. Constants and configuration
4. Owned state
5. Borrowed state
6. Runtime state
7. Construction
8. Destruction
9. Capacity or validation operations
10. Public mutation
11. Public observation
12. Internal helpers
13. Tests

This is a navigational promise, not a formatter mandate.

## Central principle

> Freedom of mechanism. Stability of form.
