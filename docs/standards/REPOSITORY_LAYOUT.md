# Repository Layout

The repository root is a project interface, not a general documentation folder.

A new contributor should be able to identify the build entrypoint, operating rules, command manual, legal files, canonical root schemas, and major source directories without scanning a wall of essays or historical notes.

## Root policy

Keep a file at the repository root only when at least one of these is true:

1. it is a conventional project entry point (`README.md`, `AGENTS.md`, legal/contribution files);
2. it is a root build/package entry point required by the toolchain;
3. repository tooling treats the exact root path as canonical;
4. moving it would create a compatibility break that has not yet been migrated deliberately.

Long-form architecture, philosophy, design notes, plans, reports, roadmaps, research notes, and historical material belong under `docs/`.

Do not add a new root-level Markdown file merely because it is important.

## Canonical directories

```text
.github/       GitHub contribution and review workflow
conformance/   cross-module conformance material
docs/          human project documentation and run records
generated/     deterministic generated views
projects/      canonical reusable modules
recipes/       executable module compositions
tools/         repository, validation, and agent tooling
```

Additional source directories may exist when they have a stable technical responsibility. Avoid top-level directories that contain a single temporary task or one-off experiment.

## Documentation taxonomy

Use the narrowest established documentation category:

```text
docs/catalog/      discoverable human catalogs
docs/checklists/   maintained capability/completion ledgers
docs/concepts/     durable conceptual and architectural essays
docs/plans/        bounded future implementation requests
docs/porting/      version migration guidance
docs/reports/      completed-run evidence and handoffs
docs/roadmaps/     longer dependency/destination planning
docs/standards/    repository-wide engineering standards
```

Create a new documentation category only when existing categories are semantically wrong for repeated material.

## Plans versus reports

A plan describes intended work. It must not be linked or summarized as evidence that the planned capability exists.

A report records work that was actually executed and the evidence established by that run.

Roadmaps are longer-horizon ordering documents and must not be treated as either plans for an immediate run or proof of completed work.

## Generated material

Generated files belong under `generated/` unless an existing canonical contract explicitly requires a root path.

Do not relocate an existing root schema/index for appearance alone. Migrate its consumers and validation first, then move it deliberately if the path no longer needs to be canonical.

## Module material

Per-module documentation remains with its module under `projects/<id>-<name>/` because the source, README, MASTERY, DETAILS, `details.json`, tests, and port contract form one reusable unit.

Do not centralize module-specific contracts into `docs/` merely to make the tree look uniform.

## Temporary material

Do not commit task logs, screenshots, local test output, downloaded binaries, caches, archives, virtual environments, editor state, QEMU scratch images, or ad hoc benchmark output to the repository root.

If an artifact is required as permanent evidence, give it a canonical textual representation and place it in the appropriate evidence/report structure.

## Moving existing files

Before moving an established path:

1. identify whether repository tooling consumes the exact path;
2. update canonical references in the same change;
3. run link/path-sensitive validation;
4. avoid cosmetic relocation when compatibility risk exceeds the organizational benefit.

Repository organization exists to reduce navigation and reasoning cost. It must not create path churn that makes the repository harder to use.
