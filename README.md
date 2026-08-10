# zig-reference

> **Solved once. Documented completely. Reused forever.**

`zig-reference` is a cumulative systems-engineering project targeting Zig 0.14.0. It develops reusable low-level modules, machine-readable engineering contracts, and an RV64 kernel used to pressure-test those ideas against real machine boundaries.

The project has three connected layers:

- **Z-Ref** — reusable systems knowledge: source, contracts, dependencies, failure behavior, diagnostics, validation, evidence, and porting knowledge.
- **Morphic** — machine-independent composition intended to preserve behavior across different machine bodies.
- **Alpz** — the RV64 kernel currently exercising the repository against paging, privilege, userspace, ELF loading, Linux-compatibility, and later virtualization requirements.

## Status

The current completed machine milestone is **Batch 23**.

Under real `qemu-system-riscv64` execution, Alpz has demonstrated:

```text
S-mode execution
→ synchronous and timer traps
→ allocator-owned physical frames
→ active Sv39
→ RX / R-NX / RW-NX permission domains
→ real S→U→S transitions
→ ECALL service and return to U-mode
→ bounded real copy-IN and copy-OUT
→ bounded RV64 ELF load planning
→ real RV64 ELF execution from parsed e_entry
→ separate R-X and RW- PT_LOAD segments
→ initialized writable data
→ non-empty BSS zeroed before U-mode
→ U-mode mutation of ELF-backed writable storage
→ supervisor observation of that mutation in the backing frame
```

The next planned boundary is **Batch 24A**: a reusable bounded RV64 Linux initial-process-stack planner for `argc`, `argv`, `envp`, and `auxv`.

The Batch 23 proof record is [`docs/reports/AGENTIC_SNOWBALL_BATCH_23.md`](docs/reports/AGENTIC_SNOWBALL_BATCH_23.md). The next implementation request is [`docs/plans/CODEX_AGENTIC_SNOWBALL_BATCH_24A_BOUNDED_RV64_LINUX_INITIAL_STACK_PLAN.txt`](docs/plans/CODEX_AGENTIC_SNOWBALL_BATCH_24A_BOUNDED_RV64_LINUX_INITIAL_STACK_PLAN.txt).

The kernel progression above was assembled during the repository's first week of development. That pace is useful evidence for the cumulative-engineering experiment, but it is not a substitute for the much larger compatibility work still ahead.

## Direction

The intended progression is:

```text
reusable systems primitives
        ↓
real RV64 kernel
        ↓
Linux-compatible process startup
        ↓
Linux syscall / fd / VFS / memory / process semantics
        ↓
BusyBox and musl
        ↓
Alpine
        ↓
QEMU/TCG running inside Alpz
        ↓
Alpz testing a newer Alpz
        ↓
recursive differential qualification
        ↓
RISC-V H-extension virtualization
        ↓
VMM
        ↓
possible /dev/kvm-compatible interface
```

This is a roadmap, not a completion claim. The working batch numbers are planning bands and may change as real workloads expose the actual dependency structure.

See [`docs/roadmaps/ALPZ_TO_ALPINE_QEMU_KVM_AND_BEYOND.md`](docs/roadmaps/ALPZ_TO_ALPINE_QEMU_KVM_AND_BEYOND.md).

## Engineering model

The repository is built around one rule: expensive discoveries should become cheap future dependencies.

```text
solve one boundary
      ↓
record its contract
      ↓
record failure behavior
      ↓
record focused validation
      ↓
make it discoverable
      ↓
reuse it in the next boundary
```

Reusable modules normally carry source, focused tests, a human integration contract, a machine-readable `details.json`, and Zig-version migration knowledge. Repository tooling derives catalogs, dependency views, validation evidence, and agent-facing indexes from canonical sources.

Machine-specific milestones use stricter evidence where appropriate: exact observable relationships, rejection or mutation tests, real QEMU execution, explicit nonclaims, and repository-wide validation.

The detailed principles live under [`docs/concepts/`](docs/concepts/) and [`docs/standards/`](docs/standards/).

## Repository layout

```text
.github/       contribution and pull-request workflow
conformance/   cross-module conformance work
docs/          plans, reports, roadmaps, standards, concepts, and indexes
generated/     deterministic generated repository views
projects/      canonical reusable modules
recipes/       executable compositions
tools/         repository, validation, and agent tooling
AGENTS.md      repository engineering rules for humans and agents
COMMANDS.md    canonical command manual
README.md      project entry point
build.zig      root Zig build graph
```

Root-level schemas and generated indexes remain at the root where repository tooling expects their canonical paths. Long-form design and vision documents belong under `docs/`.

See [`docs/README.md`](docs/README.md) for the documentation map and [`docs/standards/REPOSITORY_LAYOUT.md`](docs/standards/REPOSITORY_LAYOUT.md) for placement rules.

## Getting started

The repository targets Zig 0.14.0.

Create the repository-local Python environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements.txt
python3 tools/python-environment.py --check
```

For a zero-context repository entry:

```sh
python3 tools/query-reference.py agent bootstrap
python3 tools/query-reference.py agent doctor
```

Query before reading broad source:

```sh
python3 tools/query-reference.py capability "bounded binary parsing"
python3 tools/query-reference.py agent decide "YOUR TASK"
```

## Validation

Run the broad repository gates:

```sh
zig build check
python3 tools/developer-command.py validate-repository
```

Focused module and machine commands are documented in [`COMMANDS.md`](COMMANDS.md).

Do not weaken a gate merely to make new work pass. Fix the work or narrow the claim.

## Documentation

Start with [`docs/README.md`](docs/README.md).

Key entry points:

- [`AGENTS.md`](AGENTS.md) — repository engineering rules and agent workflow.
- [`COMMANDS.md`](COMMANDS.md) — canonical command manual.
- [`docs/catalog/MODULES.md`](docs/catalog/MODULES.md) — module catalog.
- [`docs/roadmaps/ALPZ_TO_ALPINE_QEMU_KVM_AND_BEYOND.md`](docs/roadmaps/ALPZ_TO_ALPINE_QEMU_KVM_AND_BEYOND.md) — long-horizon Alpz roadmap.
- [`docs/concepts/SNOWBALL_PRINCIPLE.md`](docs/concepts/SNOWBALL_PRINCIPLE.md) — cumulative-reuse model.
- [`docs/standards/SNOWBALL_YIELD.md`](docs/standards/SNOWBALL_YIELD.md) — major-run reuse accounting.
- [`docs/porting/PORTING.md`](docs/porting/PORTING.md) — Zig-version migration guide.
- [`docs/reports/AGENTIC_SNOWBALL_BATCH_23.md`](docs/reports/AGENTIC_SNOWBALL_BATCH_23.md) — current completed machine proof.

## Contributing

Contribution guidance lives in [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md).

The short version:

1. query the repository before adding a new primitive;
2. preserve existing contracts unless the change intentionally revises them;
3. keep claims narrower than the evidence;
4. run focused validation first and repository validation before handoff;
5. update `COMMANDS.md` when the runnable command surface changes;
6. leave a reviewable commit and an explicit handoff.

## Scope

Alpz is not Linux today. The project does not currently claim a Linux syscall ABI, a general process model, file descriptors/VFS, mature `mmap`/fault handling, Linux signals, futex/thread completeness, musl, BusyBox, Alpine, networking, QEMU self-hosting, SMP, production security, RISC-V H-extension virtualization, `/dev/kvm`, or production readiness.

Those are future pressures, not implied accomplishments.

## Licensing

No repository license is currently declared. Do not assume redistribution or reuse terms until a license is added explicitly.
