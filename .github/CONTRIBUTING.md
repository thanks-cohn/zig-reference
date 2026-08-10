# Contributing

`zig-reference` accepts changes to reusable modules, repository tooling, documentation, Alpz, Morphic, and the validation/evidence system.

The repository is designed so a contributor should not need private maintainer context to make a correct change. Use the checked-in contracts, query tools, plans, reports, and validation commands as the source of truth.

## Before changing code

1. Read [`../AGENTS.md`](../AGENTS.md).
2. Run:

   ```sh
   python3 tools/query-reference.py agent bootstrap
   python3 tools/query-reference.py agent doctor
   ```

3. Query existing capabilities before creating a new primitive.
4. Read the smallest relevant contract before broad source archaeology.
5. For Alpz/Linux/virtualization work, read the current completed batch report and current plan.

## Change discipline

A contribution should have one clear purpose.

When modifying a reusable module:

- preserve its documented ownership, failure, bounds, and invalidation behavior unless the change intentionally revises the contract;
- update `details.json`, human contracts, tests, and generated views when the public contract changes;
- inspect reverse impact before changing a shared foundation;
- reuse existing lower-level modules when their guarantees fit;
- do not create a parallel implementation only for naming or local convenience.

When modifying Alpz or a machine proof:

- state the exact new observable relationship being established;
- preserve earlier strict proof paths unless the change intentionally supersedes them;
- distinguish kernel-emitted evidence from independently reconstructed evidence;
- retain explicit nonclaims;
- do not convert a bounded fixture into a broad compatibility claim.

## Validation

Run focused validation first, then the repository gate.

At minimum for a repository-level change:

```sh
zig build check
python3 tools/developer-command.py validate-repository
```

Use [`../COMMANDS.md`](../COMMANDS.md) for focused module, recipe, and machine commands.

Do not weaken or bypass an applicable validation gate to make a change pass.

If a required tool or environment is unavailable, report the exact blocked command and leave the validation status explicit.

## Documentation and commands

- Put long-form project documentation under `docs/`; see [`../docs/standards/REPOSITORY_LAYOUT.md`](../docs/standards/REPOSITORY_LAYOUT.md).
- Keep `COMMANDS.md` synchronized with changes to runnable command surfaces.
- Do not hand-edit generated indexes when repository tooling derives them from canonical sources.
- Keep claims narrower than the evidence that supports them.

## Pull requests

A pull request should make review possible without reconstructing the author's reasoning from chat history.

Include:

- what changed;
- why the change is needed;
- exact proof or behavior statements established;
- validation commands actually executed and their results;
- known limitations or nonclaims;
- affected canonical paths;
- remaining work, when applicable.

For large Agentic Snowball batches, preserve the repository's normal `Snowball Yield`, `LOCATIONS`, `MINIMUS`, source-control, and next-pressure handoff conventions.

## Generated and temporary artifacts

Do not commit caches, local virtual environments, QEMU output, binaries, archives, screenshots, fuzz output, or other temporary artifacts unless a canonical repository contract explicitly requires a deterministic textual artifact.

## Review standard

A passing test is necessary evidence, not permission to overstate the result.

Prefer a smaller claim with a reproducible proof over a larger claim inferred from a successful demo.
