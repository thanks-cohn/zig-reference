# The Snowball Principle

## Definition

A constructive-memory repository should become easier to extend as it grows.

This is the **snowball principle**:

> Every completed lower module should reduce the implementation, documentation, testing, and discovery cost of several higher modules.

The repository does not grow as hundreds of isolated examples. It grows as layers of inherited guarantees.

```text
validated values
  -> checked ranges and addresses
  -> allocators and binary structures
  -> parsers, schedulers, and registries
  -> loaders, protocols, and devices
  -> databases, compilers, operating systems, and hypervisors
```

A higher module should import lower mechanisms whenever their contracts fit. It should document which guarantees it inherits and add only the new invariants unique to its layer.

## Snowball test

Before adding a module, ask:

1. Which repeated problem does it settle?
2. Which future modules can depend on it?
3. Which existing modules can it reuse?
4. Which guarantees will its dependents inherit?
5. Does it reduce future source code, search, context, and testing work?

A module with no upward reuse path may still be useful, but it is not a foundation module.

## Compounding effect

The first modules require almost everything to be written directly.

Later modules should increasingly look like composition:

```text
ELF load plan
  = bounded byte reader
  + validated enum decoder
  + validated bit flags
  + checked half-open range
  + alignment helpers
  + distinct address types
  + format-specific validation
```

The new code becomes mostly the format-specific validation because the lower repository has already settled byte access, tag validation, permissions, ranges, alignment, and address domains.

That is the desired acceleration curve.

## Completion rule

A snowball layer is complete only when its source, tests, README, MASTERY.md, DETAILS.md, details.json, build step, catalog entry, dependencies, and validation status agree.

A source file alone does not compound. A discoverable, documented, testable contract does.

## End state

The mature repository should let a person or coding agent search for capabilities, follow declared dependency edges, reuse working lower layers, and spend most of its effort on genuinely new orchestration.

> The repository snowballs when each solved problem becomes part of the starting point for every problem above it.
