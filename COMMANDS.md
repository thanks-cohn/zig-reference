# Zig Reference Command Manual

Solved once, documented completely, reused forever.

Write truth once. Derive every view. Verify continuously.

This is the canonical human-readable inventory of repository operations. Command definitions and canonical metadata remain authoritative; `PYTHONDONTWRITEBYTECODE=1 python3 tools/check-command-reference.py --check` detects drift. “Text-verified” below means executed without Zig compiler output in the foundation review. Zig steps are defined and statically inspected but remain pending Zig 0.14.0 execution unless a validation record says otherwise.

## Fast start

Provision dependency-backed Python validation once with `python3 -m venv .venv && .venv/bin/python -m pip install -r tools/requirements.txt`. Canonical build-backed checks select that interpreter through `python3 tools/python-environment.py`; prior shell activation is not required. `python3 tools/python-environment.py --check` fails early with the same repair when the environment or a declared dependency is unusable. `PYTHONDONTWRITEBYTECODE=1 python3 tools/test-python-environment.py` exercises both unactivated success and isolated missing-environment failure.

1. Inspect with `git status --short --branch`.
2. Validate contracts with the Python and Node contract checkers.
3. Regenerate indexes with `python3 tools/build-repository-index.py`.
4. Check drift with `python3 tools/build-repository-index.py --check`.
5. Query with `python3 tools/query-reference.py capability "bounded binary parsing"`.
6. Inspect order with `python3 tools/query-reference.py dependencies <module> --recursive`.
7. Run applicable Zig tests in an artifact-safe development environment.
8. Review `python3 tools/query-reference.py status`.
9. Finish with `git diff --check`, `git diff --stat`, and `git diff --numstat`.

## Status legend

| Status | Meaning |
|---|---|
| Text-verified | Available and successfully executed in a text-only environment. |
| Defined, pending | Available in source but not compiler-executed during this task. |
| Planned and defined | Interface exists; eligible targets or complete integration may still be absent. |
| Proposed | Documented direction without a command definition; never presented as runnable. |
| Deprecated / removed | Must not be used. |

## Compact command index

| Category | Commands | Status | Source of truth |
|---|---|---|---|
| Environment | `zig version`, `python3 --version`, `python3 tools/python-environment.py [--check]`, `PYTHONDONTWRITEBYTECODE=1 python3 tools/test-python-environment.py`, `node --version`, `git status`, `git diff --stat`, `git diff --numstat`, `git diff --check` | Python environment selection and regression compiler-executed in Batch 09 | installed tools, `tools/requirements.txt` |
| Contracts | `python3 tools/module-contract-consistency-checker.py`; `python3 tools/format-module-contracts.py [--check]`; `python3 tools/create-module-contract-template.py --module-id ID --canonical-name NAME [--force]` | Available | tool source |
| Ports | `node tools/check-port-contracts.js`; `node tools/port-contract-consistency-checker.js`; `node tools/format-port-contracts.js [--check]`; `node tools/generate-port-index.js`; `node tools/create-port-contract.js --module PATH [--force]`; `node tools/portability-smoke-test.js` | Available; execution status is reported separately | tool source, `port.js` |
| Indexes | `python3 tools/build-repository-index.py [--check]` | Text-verified | `tools/build-repository-index.py` |
| Graphs | `python3 tools/build-dependency-graphs.py [--check]` | Text-verified; textual output only | `tools/build-dependency-graphs.py` |
| Policy | `python3 tools/check-repository-policy.py`; `python3 tools/check-command-reference.py [--check]` | Text-verified | tool source |
| Query | `python3 tools/query-reference.py KIND [TERM] [FLAGS]` | Text-verified | `tools/query-reference.py` |
| Evidence | `python3 tools/record-validation.py --level {unit,smoke,all}`; `python3 tools/record-validation.py --check`; `zig build check-validation-evidence` | Compiler-executed in this review | `tools/record-validation.py`, `validation-evidence.schema.json` |
| Specialized | `python3 tools/test-specialized-levels.py {property,fuzz-smoke,differential}` | Planned and defined; eligible targets vary | tool source |
| Status | `python3 tools/status.py`; `python3 tools/query-reference.py status` | Available | generated health index |

All Python invocations may be prefixed with `PYTHONDONTWRITEBYTECODE=1`; this is required for strict text-only work.

## Contract and generation details

Formatting commands without `--check` modify canonical contracts. Template creators write module or port contract text and refuse replacement unless `--force` is supplied. Index and graph generators write committed derived JSON, Markdown, Mermaid, and DOT; their `--check` modes do not modify the tree. Successful generation yields deterministic, two-space JSON with a generated notice. Failures include invalid JSON/schema, stale paths, dependency cycles, contract/import mismatch, or derived drift. Related aggregate steps are `zig build check`, `zig build index`, and `zig build graph`.

`node tools/generate-port-index.js` writes `ports.json`; `node tools/format-port-contracts.js` writes canonical `port.js` formatting. Portability checks read the Zig 0.14.0 contracts and do not prove a later compiler version. Inspect `port.js`, then query `python3 tools/query-reference.py port-order --target 0.16.0`; this gives migration order, not compatibility evidence.

## Query reference

Supported kinds and examples:

```text
python3 tools/query-reference.py module fixed-capacity-vector
python3 tools/query-reference.py capability "physical page allocation"
python3 tools/query-reference.py symbol PhysicalAddress
python3 tools/query-reference.py endpoint append
python3 tools/query-reference.py error Overflow
python3 tools/query-reference.py dependencies physical-page-frame-allocator --recursive
python3 tools/query-reference.py dependents checked-half-open-range --recursive
python3 tools/query-reference.py build-order hyper-zig
python3 tools/query-reference.py port-order --target 0.16.0
python3 tools/query-reference.py lifecycle active
python3 tools/query-reference.py maturity contracted
python3 tools/query-reference.py deprecated
python3 tools/query-reference.py replacement old-module-name
python3 tools/query-reference.py unvalidated
python3 tools/query-reference.py paths bounded-byte-reader
python3 tools/query-reference.py recipe parse-length-prefixed-record
python3 tools/query-reference.py status
```

Common flags are `--json`, `--compact` (compact JSON), `--paths-only`, `--symbols-only`, `--recursive`, and `--explain-selection`. `port-order` additionally accepts `--target`; it does not assert support. No-match, ambiguous alias, and text-only semantic matches are reported without inventing certainty.

## Repository build commands

| Command | Status in this review | Purpose / effects | Source |
|---|---|---|---|
| `zig build check` | Compiler-executed in this review | Runs contract, port, policy, command-manual, evidence, index-drift, and graph-drift checks; check mode updates nothing. | `build.zig` |
| `zig build index` | Defined, pending | Regenerates committed textual indexes. | `build.zig` |
| `zig build graph` | Defined, pending | Regenerates textual graph datasets and Mermaid/DOT reports. | `build.zig` |
| `zig build status` | Compiler-executed in this review | Prints generated evidence-backed health. | `build.zig` |
| `zig build check-validation-evidence` | Compiler-executed in this review | Checks the evidence schema contract, exact module/target identity, Zig 0.14.0 attribution, and current source digests without modifying evidence. | `build.zig` |
| `zig build query` | Defined, pending | Runs the default status query; use Python for arguments. | `build.zig` |
| `zig build recipes` | Defined, pending | Compiles and tests recipe adapters and dependencies. May create compiler output. | `build.zig` |
| `zig build conformance` | Defined, pending | Compiles and runs configured behavioral adapters without checking committed validation evidence. May create compiler output. | `build.zig` |
| `zig build property` | Planned and defined | Runs configured deterministic property targets. May create compiler output. | `build.zig` |
| `zig build fuzz-smoke` | Planned and defined | Runs bounded configured fuzz-smoke targets; never implies full fuzzing. | `build.zig` |
| `zig build differential` | Planned and defined | Runs configured oracle comparisons. | `build.zig` |
| `zig build smoke` | Defined, pending | Runs named-import external consumer tests without checking committed validation evidence. May create compiler output. | `build.zig` |
| `zig build test` | Defined, pending | Runs contracts, unit tests, and smoke tests under Zig 0.14.0 without checking committed validation evidence. | `build.zig` |
| `zig build validate-repository` | Defined, pending | Aggregates policy, unit, smoke, recipe, conformance, and specialized checks. | `build.zig` |
| `zig build check-module-contracts` | Defined, pending | Validates module contracts. | `build.zig` |
| `zig build check-port-contracts` | Defined, pending | Validates port contracts. | `build.zig` |
| `zig build format-port-contracts` | Defined, pending | Rewrites port contracts. | `build.zig` |
| `zig build generate-port-index` | Defined, pending | Rewrites `ports.json`. | `build.zig` |
| `zig build smoke-portability-infrastructure` | Defined, pending | Checks port discovery and ordering; not compiler portability. | `build.zig` |

## Module commands

The following section is derived from `generated/modules.json` and canonical module metadata. Every Zig command may create compiler/build output and was not run in the text-only task.

<!-- BEGIN GENERATED MODULE COMMANDS -->
| Module import | Unit test | External smoke test | Contract |
|---|---|---|---|
| `fixed-capacity-vector` | `zig build test-fixed-capacity-vector` | `zig build smoke-fixed-capacity-vector` | `projects/00-fixed-capacity-vector/details.json` |
| `dynamic-array` | `zig build test-dynamic-array` | `zig build smoke-dynamic-array` | `projects/01-dynamic-array/details.json` |
| `ring-buffer` | `zig build test-ring-buffer` | `zig build smoke-ring-buffer` | `projects/02-ring-buffer/details.json` |
| `bit-set` | `zig build test-bit-set` | `zig build smoke-bit-set` | `projects/03-bit-set/details.json` |
| `bounded-byte-reader` | `zig build test-bounded-byte-reader` | `zig build smoke-bounded-byte-reader` | `projects/04-bounded-byte-reader/details.json` |
| `stack` | `zig build test-stack` | `zig build smoke-stack` | `projects/05-stack/details.json` |
| `byte-writer` | `zig build test-byte-writer` | `zig build smoke-byte-writer` | `projects/06-byte-writer/details.json` |
| `bitmap-allocator` | `zig build test-bitmap-allocator` | `zig build smoke-bitmap-allocator` | `projects/07-bitmap-allocator/details.json` |
| `generational-handles` | `zig build test-generational-handles` | `zig build smoke-generational-handles` | `projects/08-generational-handles/details.json` |
| `state-machine` | `zig build test-state-machine` | `zig build smoke-state-machine` | `projects/09-state-machine/details.json` |
| `checked-integer-cast` | `zig build test-checked-integer-cast` | `zig build smoke-checked-integer-cast` | `projects/10-checked-integer-cast/details.json` |
| `nonzero-integer` | `zig build test-nonzero-integer` | `zig build smoke-nonzero-integer` | `projects/11-nonzero-integer/details.json` |
| `bounded-integer` | `zig build test-bounded-integer` | `zig build smoke-bounded-integer` | `projects/12-bounded-integer/details.json` |
| `saturating-counter` | `zig build test-saturating-counter` | `zig build smoke-saturating-counter` | `projects/13-saturating-counter/details.json` |
| `validated-enum-decoder` | `zig build test-validated-enum-decoder` | `zig build smoke-validated-enum-decoder` | `projects/14-validated-enum-decoder/details.json` |
| `aligned-address-and-size-helpers` | `zig build test-aligned-address-and-size-helpers` | `zig build smoke-aligned-address-and-size-helpers` | `projects/15-aligned-address-and-size-helpers/details.json` |
| `validated-bit-flags` | `zig build test-validated-bit-flags` | `zig build smoke-validated-bit-flags` | `projects/16-validated-bit-flags/details.json` |
| `checked-half-open-range` | `zig build test-checked-half-open-range` | `zig build smoke-checked-half-open-range` | `projects/17-checked-half-open-range/details.json` |
| `distinct-memory-address-types` | `zig build test-distinct-memory-address-types` | `zig build smoke-distinct-memory-address-types` | `projects/18-distinct-memory-address-types/details.json` |
| `wrapping-sequence-number` | `zig build test-wrapping-sequence-number` | `zig build smoke-wrapping-sequence-number` | `projects/19-wrapping-sequence-number/details.json` |
| `optional-typed-handle` | `zig build test-optional-typed-handle` | `zig build smoke-optional-typed-handle` | `projects/20-optional-typed-handle/details.json` |
| `unit-safe-quantity` | `zig build test-unit-safe-quantity` | `zig build smoke-unit-safe-quantity` | `projects/21-unit-safe-quantity/details.json` |
| `endian-integer-codec` | `zig build test-endian-integer-codec` | `zig build smoke-endian-integer-codec` | `projects/22-endian-integer-codec/details.json` |
| `validated-ascii-byte` | `zig build test-validated-ascii-byte` | `zig build smoke-validated-ascii-byte` | `projects/23-validated-ascii-byte/details.json` |
| `fourcc-code` | `zig build test-fourcc-code` | `zig build smoke-fourcc-code` | `projects/24-fourcc-code/details.json` |
| `semantic-version` | `zig build test-semantic-version` | `zig build smoke-semantic-version` | `projects/25-semantic-version/details.json` |
| `tagged-result` | `zig build test-tagged-result` | `zig build smoke-tagged-result` | `projects/26-tagged-result/details.json` |
| `source-span` | `zig build test-source-span` | `zig build smoke-source-span` | `projects/27-source-span/details.json` |
| `physical-page-frame-number-and-address-conversion` | `zig build test-physical-page-frame-number-and-address-conversion` | `zig build smoke-physical-page-frame-number-and-address-conversion` | `projects/28-physical-page-frame-number-and-address-conversion/details.json` |
| `binary-cursor-checkpoint` | `zig build test-binary-cursor-checkpoint` | `zig build smoke-binary-cursor-checkpoint` | `projects/29-binary-cursor-checkpoint/details.json` |
| `bounded-binary-sub-reader` | `zig build test-bounded-binary-sub-reader` | `zig build smoke-bounded-binary-sub-reader` | `projects/30-bounded-binary-sub-reader/details.json` |
| `length-prefixed-binary-field` | `zig build test-length-prefixed-binary-field` | `zig build smoke-length-prefixed-binary-field` | `projects/31-length-prefixed-binary-field/details.json` |
| `type-length-value-decoder` | `zig build test-type-length-value-decoder` | `zig build smoke-type-length-value-decoder` | `projects/32-type-length-value-decoder/details.json` |
| `owned-byte-buffer` | `zig build test-owned-byte-buffer` | `zig build smoke-owned-byte-buffer` | `projects/33-owned-byte-buffer/details.json` |
| `fixed-capacity-object-pool` | `zig build test-fixed-capacity-object-pool` | `zig build smoke-fixed-capacity-object-pool` | `projects/34-fixed-capacity-object-pool/details.json` |
| `physical-memory-region-set` | `zig build test-physical-memory-region-set` | `zig build smoke-physical-memory-region-set` | `projects/35-physical-memory-region-set/details.json` |
| `physical-page-frame-allocator` | `zig build test-physical-page-frame-allocator` | `zig build smoke-physical-page-frame-allocator` | `projects/36-physical-page-frame-allocator/details.json` |
| `elf64-file-header-parser` | `zig build test-elf64-file-header-parser` | `zig build smoke-elf64-file-header-parser` | `projects/37-elf64-file-header-parser/details.json` |
| `elf64-program-header-parser` | `zig build test-elf64-program-header-parser` | `zig build smoke-elf64-program-header-parser` | `projects/38-elf64-program-header-parser/details.json` |
| `intrusive-doubly-linked-list` | `zig build test-intrusive-doubly-linked-list` | `zig build smoke-intrusive-doubly-linked-list` | `projects/39-intrusive-doubly-linked-list/details.json` |
| `fixed-free-list` | `zig build test-fixed-free-list` | `zig build smoke-fixed-free-list` | `projects/40-fixed-free-list/details.json` |
| `fixed-bump-allocator` | `zig build test-fixed-bump-allocator` | `zig build smoke-fixed-bump-allocator` | `projects/41-fixed-bump-allocator/details.json` |
| `fixed-capacity-priority-queue` | `zig build test-fixed-capacity-priority-queue` | `zig build smoke-fixed-capacity-priority-queue` | `projects/42-fixed-capacity-priority-queue/details.json` |
| `fixed-capacity-topological-sort` | `zig build test-fixed-capacity-topological-sort` | `zig build smoke-fixed-capacity-topological-sort` | `projects/43-fixed-capacity-topological-sort/details.json` |
| `riscv-sv39-page-table-entry` | `zig build test-riscv-sv39-page-table-entry` | `zig build smoke-riscv-sv39-page-table-entry` | `projects/44-riscv-sv39-page-table-entry/details.json` |
| `riscv-sv39-virtual-address-indexing` | `zig build test-riscv-sv39-virtual-address-indexing` | `zig build smoke-riscv-sv39-virtual-address-indexing` | `projects/45-riscv-sv39-virtual-address-indexing/details.json` |
| `riscv-page-table-page-owner` | `zig build test-riscv-page-table-page-owner` | `zig build smoke-riscv-page-table-page-owner` | `projects/46-riscv-page-table-page-owner/details.json` |
| `riscv-sv39-page-table-walker` | `zig build test-riscv-sv39-page-table-walker` | `zig build smoke-riscv-sv39-page-table-walker` | `projects/47-riscv-sv39-page-table-walker/details.json` |
| `riscv-sfence-vma-invalidation` | `zig build test-riscv-sfence-vma-invalidation` | `zig build smoke-riscv-sfence-vma-invalidation` | `projects/48-riscv-sfence-vma-invalidation/details.json` |
| `riscv-sv39-page-table-builder` | `zig build test-riscv-sv39-page-table-builder` | `zig build smoke-riscv-sv39-page-table-builder` | `projects/49-riscv-sv39-page-table-builder/details.json` |
| `bounded-system-resource-plan` | `zig build test-bounded-system-resource-plan` | `zig build smoke-bounded-system-resource-plan` | `projects/50-bounded-system-resource-plan/details.json` |
| `bounded-deterministic-event-trace` | `zig build test-bounded-deterministic-event-trace` | `zig build smoke-bounded-deterministic-event-trace` | `projects/51-bounded-deterministic-event-trace/details.json` |
| `bounded-deterministic-scheduler` | `zig build test-bounded-deterministic-scheduler` | `zig build smoke-bounded-deterministic-scheduler` | `projects/52-bounded-deterministic-scheduler/details.json` |
| `bounded-user-memory-transfer-plan` | `zig build test-bounded-user-memory-transfer-plan` | `zig build smoke-bounded-user-memory-transfer-plan` | `projects/53-bounded-user-memory-transfer-plan/details.json` |
| `bounded-elf64-load-plan` | `zig build test-bounded-elf64-load-plan` | `zig build smoke-bounded-elf64-load-plan` | `projects/54-bounded-elf64-load-plan/details.json` |
| `bounded-rv64-linux-initial-stack-plan` | `zig build test-bounded-rv64-linux-initial-stack-plan` | `zig build smoke-bounded-rv64-linux-initial-stack-plan` | `projects/55-bounded-rv64-linux-initial-stack-plan/details.json` |
| `morphic-semantic-operation` | `zig build test-morphic-semantic-operation` | `zig build smoke-morphic-semantic-operation` | `projects/56-morphic-semantic-operation/details.json` |
| `bounded-resource-table` | `zig build test-bounded-resource-table` | `zig build smoke-bounded-resource-table` | `projects/57-bounded-resource-table/details.json` |
| `bounded-filesystem` | `zig build test-bounded-filesystem` | `zig build smoke-bounded-filesystem` | `projects/58-bounded-filesystem/details.json` |
| `bounded-address-space-exec-image` | `zig build test-bounded-address-space-exec-image` | `zig build smoke-bounded-address-space-exec-image` | `projects/59-bounded-address-space-exec-image/details.json` |
<!-- END GENERATED MODULE COMMANDS -->

## Recipes and conformance

List or inspect recipes with `find recipes -mindepth 1 -maxdepth 1 -type d -print | sort` and `python3 tools/query-reference.py recipe NAME`. The composition recipes include `plan-bounded-initialization`; the original six are `construct-bounded-state-machine`, `create-stale-safe-object-registry`, `normalize-checked-memory-range`, `parse-length-prefixed-record`, `validate-physical-page-frame`, and `write-and-read-explicit-endian-record`. `zig build recipes` is the aggregate command; each has a `zig build test-recipe-<name>` step defined from `recipe_specs` in `build.zig`. These compiler-driven steps remain pending in this review.

Suites are `allocator`, `binary-writer`, `bounded-reader`, `fixed-capacity-container`, `growable-container`, `handle-registry`, `integer-codec`, and `range-value`. Inspect `conformance/<suite>/suite.json`; run configured adapters with `zig build conformance`. Presence of metadata is not conformance evidence, and no per-suite build steps currently exist. Use `python3 tools/query-reference.py unvalidated` to locate modules without unit evidence.

## Property, fuzz, differential, and evidence

Testing is risk-based; not every module is eligible. `zig build property`, `zig build fuzz-smoke`, and `zig build differential` are defined aggregate interfaces. A zero-target run is infrastructure status, not module evidence. The eight conformance suite declarations currently reuse module unit tests and explicitly set `dedicated_shared_adapter` and `maturity_credit` false, so `zig build conformance` earns no per-module conformance credit.

Passing evidence may only be produced by `PYTHONDONTWRITEBYTECODE=1 python3 tools/record-validation.py --level unit`, `--level smoke`, or `--level all`. The generator obtains `zig version`, runs every exact canonical `zig build test-<module>` and/or `zig build smoke-<module>` target, stops on the first failure, and writes a single deterministic `generated/validation/modules.json`. It intentionally records no wall-clock timestamp. Each record names the module, target, Zig version, native target and optimization, baseline Git revision, and a SHA-256 digest over root build wiring, its canonical source, contract, and external smoke source. Normal development intentionally separates behavior from evidence freshness: first modify source; run unit, smoke, recipe, and conformance behavior with `zig build test`, `zig build smoke`, `zig build recipes`, and `zig build conformance`; regenerate evidence with `PYTHONDONTWRITEBYTECODE=1 python3 tools/record-validation.py --level all`; regenerate indexes with `PYTHONDONTWRITEBYTECODE=1 python3 tools/build-repository-index.py`; then run `zig build check-validation-evidence`, `zig build check`, `zig build status`, and `zig build validate-repository`. Non-mutating drift validation remains available through `PYTHONDONTWRITEBYTECODE=1 python3 tools/record-validation.py --check` or `zig build check-validation-evidence`, and aggregate repository gates (`zig build check`, `zig build status`, and `zig build validate-repository`) still enforce current committed evidence. Behavioral aggregate runs (`zig build test`, `smoke`, and `conformance`) do not reject stale committed evidence before executing tests and do not rewrite Git-tracked evidence.

The generated status interprets a current unit pass as maturity level 3 and requires that pass plus a current smoke pass for level 4. Conformance is a separate counter and does not raise maturity under the current level policy. Levels 5–9 still require advanced, reuse, system, review, and stability evidence described in `docs/standards/MATURITY_LEVELS.md`; therefore smoke-tested experimental modules are not called stable or system proven.

## Contribution and CI equivalence

```text
git status
git switch -c <branch>
git diff
git diff --check
git add <paths>
git diff --cached
git commit -m "<message>"
git push -u origin <branch>
```

Run the strongest applicable checks before committing. CI maps formatting to `python3 tools/format-module-contracts.py --check` and `zig fmt --check`; contracts/policy to `zig build check`; drift to the index and graph `--check` commands; then smoke, recipe, conformance, specialized, unit, and aggregate validation steps. GitHub permissions, runner images, secrets, and branch protection cannot be reproduced or configured locally by a repository command.

## Release preparation

No release, signing, SBOM, attestation, or artifact-publication command is currently defined. The proposed process is documented in `docs/standards/RELEASE_PROVENANCE.md`; it remains intentionally non-runnable until real reproducibility and authority exist.

## Prohibited and removed commands

Database generators, SQLite generation, binary indexes, rendered graph generation, and a database build step are removed and unsupported. Deterministic JSON indexes are the complete acceleration layer. Repository generation supports reviewable text only.

## RISC-V Sv39 foundation commands
Each module has `zig build test-<module>` and `zig build smoke-<module>` targets for `riscv-sv39-page-table-entry`, `riscv-sv39-virtual-address-indexing`, `riscv-page-table-page-owner`, `riscv-sv39-page-table-walker`, `riscv-sfence-vma-invalidation`, and `riscv-sv39-page-table-builder`. Run the composition independently with `zig build test-recipe-construct-and-verify-sv39-address-space`.

## Agent-readable pilot commands

<!-- CURRENT AGENT CORPUS --> Agent Fast Path v2 currently projects 60 contracted modules as 58 full cards with 2 partial cards.
Batch 26 established compiler-passing focused unit and smoke behavior for modules 58 and 59 and reran the inherited Batch 25B mutation and two-QEMU proof; the still-missing Batch 26 machine integration is recorded honestly in `docs/reports/AGENTIC_SNOWBALL_BATCH_26.md`.
The Batch 07 repair revalidated bootstrap/doctor discovery, deterministic preflight, command-reference drift, ports, Developer Minimus, hosted Morphic verification, and the complete repository pipeline under Zig 0.14.0; exact results are recorded in `docs/reports/AGENTIC_SNOWBALL_BATCH_07_REPAIR.md`.
The root-document policy is checked by `node tools/check-port-contracts.js`; it accepts
only the explicit flagship/root allowlist and rejects any other root Markdown file.

| Command | Purpose |
|---|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/build-agent-index.py [--check]` | Generate or check the compact deterministic agent projection. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/validate-agent-contracts.py [--self-test]` | Validate pilot contracts/proof evidence or run negative validator tests. |
| `zig build validate-agent-contracts` | Run the agent contract validator and generated-index drift check. |
| `python3 tools/query-reference.py agent capability TERM` | Discover pilot modules by controlled capability ID. |
| `python3 tools/query-reference.py agent module NAME` | Inspect a compact pilot module projection. |
| `python3 tools/query-reference.py agent diagnostic ID` | Locate misuse evidence and its repair. |
| `python3 tools/query-reference.py agent diagnose TERM` | Return at most five deterministic diagnostic candidates matched from authored IDs, aliases, native errors, modules, operations, or summaries; unmatched terms remain explicitly unknown. |
| `python3 tools/query-reference.py agent symbol SYMBOL` | Discover a pilot module by public symbol. |
| `python3 tools/query-reference.py agent pending` | List modules awaiting migration without calling them invalid. |

Batch 05 validated the 52-card projection and Debug Fast Path under Zig 0.14.0. Exact historical aliases resolve to canonical identities; `diagnose` is candidate discovery rather than causal inference, and native error text remains authoritative when a symptom is ambiguous or unknown.
| `python3 tools/query-reference.py agent bootstrap` | Return the compact zero-context repository entry card. |
| `python3 tools/query-reference.py agent doctor` | Check fast-path prerequisites, drift, contracts, and Zig 0.14.0. |
| `python3 tools/query-reference.py agent card MODULE --view {select,integrate,repair,all}` | Return a purpose-sized module card. |
| `python3 tools/query-reference.py agent preflight MODULE_OR_RECIPE` | Return deterministic compact JSON containing correctness obligations, explicit unknowns, minimum locations, and validation closure before integration. |
| `python3 tools/query-reference.py agent decide "TASK"` | Rank or reject up to three modules by deterministic contract matching. |
| `python3 tools/query-reference.py agent compose CAPABILITY [...]` | Resolve provided, ambiguous, and missing capabilities plus closure and recipes. |
| `python3 tools/query-reference.py agent impact MODULE` | Derive downstream modules, recipes, and validation commands. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/test-agent-fast-path.py` | Run the deterministic zero-context acceptance test. |

Batch 03 established the prior 37/15 projection, including explicit DynamicArray borrowed-view semantics and the `Entry.decode` Sv39 page-table-entry construction path. The acceptance test guards both semantic projections.

## Bounded system resource plan commands

- `zig build plan-morphic-runtime` prints the canonical plan.
- `zig build verify-morphic-plan` runs deterministic composition, negative, storage, and agent-contract checks.
- `zig build trace-morphic-example` prints the canonical normalized Morphic event trace.
- `zig build test-recipe-trace-morphic-example` tests the 4096-capacity composition.
- `zig build verify-morphic-trace` runs module unit, external smoke, recipe, and agent checks.

## Developer handoff output (Batch 04 repair)

Raw `zig build` commands remain implementation surfaces and preserve normal Zig output; they do not claim to append output after Zig's own final Build Summary. Use the single canonical outer driver below for build-backed serious checks. It streams the underlying command's ordinary output, waits for completion, appends exactly one `LOCATIONS` then `MINIMUS` handoff for the invoked outer operation, and preserves the underlying exit status. Direct Agent Fast Path doctor remains a canonical Python surface.

| Canonical command | Purpose |
|---|---|
| `python3 tools/query-reference.py agent doctor` | Check Agent Fast Path prerequisites and end its JSON output with its own handoff. |
| `python3 tools/developer-command.py smoke` | Run `zig build smoke --summary all` and append the final aggregate-smoke handoff. |
| `python3 tools/developer-command.py validate-repository` | Run `zig build validate-repository --summary all` and append the final complete-validation handoff. |
| `python3 tools/developer-command.py verify-morphic-plan` | Run `zig build verify-morphic-plan --summary all` and append the final plan-verification handoff. |
| `python3 tools/developer-command.py verify-morphic-trace` | Run `zig build verify-morphic-trace --summary all` and append the final trace-verification handoff. |
| `python3 tools/developer-command.py verify-hosted-morphic-runtime` | Run `zig build verify-hosted-morphic-runtime --summary all` and append the final hosted-runtime verification handoff. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/test-developer-minimus.py` | Test deterministic formatting, ordering, existing locations, doctor output, controlled success/failure, singular handoffs, and exit preservation. |
| `node tools/test-port-public-surface.js` | Regression-test rejection of a dependency/public-surface substitution in a port contract. |

The implementation prerequisite steps ending in `-checks` and the raw public build steps never emit subordinate Minimus blocks. Batch 04 repair replaced test-only integration snippets with functional public API usage and corrected the promoted cards' semantic projections.

Raw prerequisite commands are `zig build smoke-checks`, `zig build validate-repository-checks`, `zig build verify-morphic-plan-checks`, and `zig build verify-morphic-trace-checks`. They exist for build-graph composition and deliberately emit no handoff. `python3 tools/developer-minimus.py --command COMMAND --summary TEXT [--status {PASS,FAIL,PARTIAL}] [--failure TEXT] [--next COMMAND] [--modules] [--location LABEL=RELATIVE_PATH ...]` is the internal deterministic formatter used by the doctor and outer driver; developers normally use the canonical surfaces above.

## Hosted Morphic runtime composition commands

Batch 06 established these Zig 0.14.0 command surfaces and validated them in this run:

- `zig build test-bounded-deterministic-scheduler` runs the scheduler unit tests.
- `zig build smoke-bounded-deterministic-scheduler` runs its external-consumer smoke test.
- `zig build test-recipe-run-hosted-morphic-runtime` checks bounded execution, explicit output exhaustion, and byte repeatability.
- `zig build run-hosted-morphic-runtime` prints the canonical capturable output followed by its normalized event trace.
- `zig build run-fake-morphic-runtime` executes the same core through the deterministic bounded fake machine and prints the comparable output and trace.
- `zig build verify-hosted-morphic-runtime` validates the hosted recipe and Agent Fast Path contracts.
- `zig build install-riscv64-morphic-runtime -Dtarget=riscv64-linux-musl --prefix PATH` cross-compiles and installs the same Morphic executable as a static riscv64 Linux userspace artifact at `PATH/bin/run-hosted-morphic-runtime`; it does not execute the artifact.
- `python3 tools/verify-riscv64-morphic-runtime.py` is the canonical execution-lab verification: it builds that artifact, confirms its RISC-V ELF machine identity with `readelf`, executes native hosted/fake and QEMU riscv64 runs twice, compares all canonical bytes, and appends one Developer Minimus handoff. It requires external `qemu-riscv64` and `readelf` commands and is intentionally not part of ordinary repository validation.
- `zig build install-freestanding-riscv64-morphic-runtime --prefix PATH` builds the distinct `riscv64-freestanding-none` ELF payload at `PATH/bin/morphic-freestanding-riscv64`; it has entry address `0x80200000` for the QEMU `virt` OpenSBI payload convention and does not execute it.
- `python3 tools/verify-freestanding-riscv64-morphic-runtime.py` is the canonical Batch 11 system-execution lab. It inspects the freestanding ELF, rejects an interpreter, runs native hosted/fake and two bounded `qemu-system-riscv64 -machine virt -nographic -bios default -kernel ...` executions, extracts exactly one explicit frame, compares payload bytes, and appends one handoff. It requires `qemu-system-riscv64` and `readelf` and remains outside ordinary validation.
- `python3 tools/verify-freestanding-riscv64-supervisor-trap.py` is the canonical Batch 12 system-execution lab. It builds and inspects that same freestanding ELF, runs it twice under bounded system QEMU, requires exactly one synchronous breakpoint trap through the payload's `stvec`, checks the fixed trap record, return/resume and representative integer-register/stack preservation evidence, and then compares the independently framed Morphic bytes with both native paths. It requires `qemu-system-riscv64` and `readelf` and remains outside ordinary validation.
- `python3 tools/verify-freestanding-riscv64-supervisor-timer.py` is the canonical Batch 13 system-execution lab. It preserves the ELF-anchored Batch 12 breakpoint proof, executes two bounded real system-QEMU machines, requires exactly one asynchronous supervisor timer cause-5 record through the same `stvec`, bounds the interrupted PC with ELF symbols, checks unchanged interrupt `sepc`, the explicit STIE-mask/set-timer-max one-shot policy, context restoration and `sret` return, rejects duplicate delivery, and compares the canonical Morphic bytes with both native paths. It requires `qemu-system-riscv64` and `readelf` and remains outside ordinary validation.
- `python3 tools/verify-riscv64-morphic-runtime.py --self-test`, `python3 tools/verify-freestanding-riscv64-morphic-runtime.py --self-test`, `python3 tools/verify-freestanding-riscv64-supervisor-trap.py --self-test`, and `python3 tools/verify-freestanding-riscv64-supervisor-timer.py --self-test` run focused ELF-field, timeout, framing, trap/timer-record, policy, and failure-path regressions without QEMU.

Batch 12 executed both freestanding execution labs with QEMU 8.2.2/OpenSBI 1.3: the real S-mode breakpoint trap returned and both native paths and both real system-machine runs produced the same 765-byte Morphic artifact. Ordinary repository validation still does not invoke QEMU.

Batch 13 executed the Linux-user, freestanding, synchronous-trap, and supervisor-timer labs with QEMU 8.2.2/OpenSBI 1.3. Two timer runs each delivered exactly one asynchronous supervisor timer interrupt (interrupt bit 1, cause 5), completed the STIE-mask/set-timer-max one-shot policy, returned through `sret`, and preserved the same 765-byte Morphic artifact. Ordinary repository validation remains independent of QEMU.

The raw `zig build verify-hosted-morphic-runtime` step is an implementation surface. The canonical serious outer verification is `python3 tools/developer-command.py verify-hosted-morphic-runtime`, which preserves Zig output and exit status and appends exactly one `LOCATIONS` then `MINIMUS` handoff.

## Invariant-Guided Diagnosis (Batch 08)

Free-text `python3 tools/query-reference.py agent diagnose TERM` remains bounded deterministic candidate discovery; it does not claim causality. Structured diagnosis uses `python3 tools/query-reference.py agent diagnose --capsule PATH`, validates the JSON Failure State Capsule, and returns `KNOWN` only when observed values establish one canonical invariant. Insufficient evidence returns explicit `UNKNOWN`; malformed capsules return nonzero with `ZIGREF-FAILURE-CAPSULE-INVALID`.

| Command | Purpose |
|---|---|
| `python3 tools/query-reference.py agent diagnose --capsule PATH` | Diagnose a schema-valid Failure State Capsule from canonical generated invariant truth. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tools/test-invariant-diagnosis.py` | Validate capsule fixtures, known/unknown/invalid behavior, and byte-repeatability. |

The canonical capsule schema is `schemas/failure-state-capsule.schema.json`. Batch 08 pressure-tested temporal progression, declared resource bounds, and bounded trace capacity without adding a module or recipe; Agent Fast Path remains 53 contracted / 53 full / 0 partial.

## Bounded monotonic supervisor tick commands (Batch 14)

- `python3 tools/verify-freestanding-riscv64-supervisor-ticks.py --self-test` checks repeated-tick framing, exact count/return reconciliation, cause classification, strict monotonic time, deadline chaining, non-final re-arm, final neutralization, ELF-bound, and failure-path parsing without QEMU.
- `python3 tools/verify-freestanding-riscv64-supervisor-ticks.py` is the canonical Batch 14 execution lab. It builds and inspects the current freestanding RISC-V ELF, preserves the Batch 12 breakpoint and Batch 13 one-shot proofs, runs two bounded real `qemu-system-riscv64` machines, requires exactly four cause-5 supervisor timer deliveries and four post-`sret` returns per run, verifies fresh-observed-time-plus-100000 re-arming and final STIE-mask/maximum-deadline neutralization with no extra tick, compares the unchanged Morphic bytes with native hosted/fake paths, and appends one Developer Minimus handoff. It requires `qemu-system-riscv64` and `readelf` and remains outside ordinary repository validation.

Batch 14 executed the complete Batch 10–14 lab matrix with QEMU 8.2.2/OpenSBI 1.3. The repeated-tick lab delivered four strictly monotonic asynchronous supervisor timer ticks in each of two real machines, explicitly re-armed all three non-final deliveries, neutralized the fourth, returned through `sret` four times, observed no fifth delivery, and preserved the 765-byte canonical Morphic artifact. Ordinary repository validation remains independent of QEMU.

## Scheduler-facing monotonic supervisor time commands (Batch 15)

- `python3 tools/verify-freestanding-riscv64-scheduler-time.py --self-test` rejection-tests the distinct bounded scheduler-time frame, exact real-time identity mapping, monotonicity, readiness thresholds, stable ordering, after-`sret` decision phase, completion, and prior-proof framing without QEMU.
- `python3 tools/verify-freestanding-riscv64-scheduler-time.py` is the canonical Batch 15 execution lab. It builds and inspects the freestanding ELF, runs two bounded real system-QEMU machines, feeds exactly four recorded `rdtime` values per run through the existing scheduler after all four corresponding `sret` returns, independently verifies identity mapping, monotonic scheduler time, readiness counts `[1,2,0,1]`, stable selection `[1@0,2@1,3@1,4@3]`, Batch 12/13/14 frames, and exact 765-byte native/fake/machine Morphic equality, then appends one Developer Minimus handoff. It does not prove preemption, clock units or accuracy, sleeping, POSIX/Linux time, U-mode, or real hardware behavior.

Batch 15 executed the focused lab with QEMU 8.2.2/OpenSBI 1.3. Each of two machines supplied four strictly monotonic real `rdtime` observations through the identity `u64` scheduler-facing adapter; all scheduler advancement and selection occurred in normal S-mode after the four matching `sret` returns. Ordinary repository validation remains independent of QEMU.

## Bounded freestanding physical-memory ownership commands (Batch 16)

- `python3 tools/verify-freestanding-riscv64-physical-memory.py --self-test` rejection-tests the distinct physical-memory frame, ELF/runtime pool agreement, 4096-byte alignment, actual Bare `satp`, unique in-pool PFN/address conversion, bounded sentinel access, exhaustion, release/double-free/foreign-frame behavior, deterministic reacquisition, accounting, prior proof frames, and Morphic bytes without QEMU.
- `python3 tools/verify-freestanding-riscv64-physical-memory.py` is the canonical Batch 16 execution lab. It independently reads the linker-owned eight-page pool and stack symbols from the ELF, runs two bounded real system-QEMU machines, proves runtime bounds and actual Bare translation, exercises the existing `PhysicalMemoryRegionSet` and `PhysicalPageFrameAllocator`, checks real sentinel write/read relationships for all eight frames, and preserves Batch 12/13/14/15 plus exact 765-byte Morphic equality. It does not discover platform RAM, activate Sv39, or claim a production physical-memory manager.

Batch 16 executed both commands with Zig 0.14.0 and QEMU 8.2.2. The real ELF/runtime pool was `[0x80214000,0x8021c000)`, both machines allocated eight unique bounded frames, the ninth allocation exhausted, release rejections and deterministic reacquisition matched the existing allocator contract, final accounting was eight free/zero allocated, and the canonical Morphic artifact remained 765 bytes.

## Active Sv39 kernel continuation commands (Batch 17)

- `python3 tools/verify-freestanding-riscv64-active-sv39.py --self-test` rejection-tests strict Batch 17 framing, owned and unique page-table frames, raw `satp` decoding, ASID/root agreement, exact ELF mapping coverage, SFENCE.VMA evidence, continuation state, non-identity alias resolution/sentinels, proof ordering, and Batch 12–16/Morphic preservation without QEMU.
- `python3 tools/verify-freestanding-riscv64-active-sv39.py` is the canonical Batch 17 execution lab. It independently inspects the ELF continuation and eight-page pool, executes two bounded real `qemu-system-riscv64` machines, requires an actual Sv39 `satp` whose root is one of four zeroed page-table frames allocated from that pool, checks a global SFENCE.VMA boundary and the real `0x80400000` alias of an owned data frame, and proves the unchanged 765-byte Morphic artifact executes afterward while paging remains active.

Batch 17 executed both commands with Zig 0.14.0 and QEMU 8.2.2. Both real machines installed Sv39 with ASID 0, an owned root at `0x80215000`, four owned page-table pages, and a non-identity `0x80400000 -> 0x8021c000` alias, then preserved Batch 12–16 and exact hosted/fake/machine Morphic equality. This is not a general VMM, hardened permission policy, higher-half design, U-mode/process address space, demand paging, SMP shootdown, syscall, or Linux ABI proof.

## Supervisor-only Sv39 permission-domain commands (Batch 18)

- `python3 tools/verify-freestanding-riscv64-sv39-permissions.py --self-test` rejection-tests strict Batch 18 framing and ordering, ELF-derived page-aligned domains, raw leaf-PTE decoding and PPN agreement, exact bounded leaf coverage, supervisor-only `U=0`, text RX, rodata R/NX, writable/alias RW/NX, `W+X=0`, live mutation/fence evidence, positive probes, Batch 12–17 preservation, and Morphic equality without QEMU.
- `python3 tools/verify-freestanding-riscv64-sv39-permissions.py` is the canonical Batch 18 execution lab. It builds and inspects the current RISC-V ELF, derives all three permission domains from linker symbols, executes two bounded real `qemu-system-riscv64` machines, independently decodes every installed 4 KiB leaf PTE, proves exact identity and translated-alias targets, requires `U=0` and `W+X=0`, checks the unchanged Sv39 root and global SFENCE.VMA boundary, preserves Batch 12–17, and proves exact 765-byte hosted/fake/two-machine Morphic equality.

Batch 18 executed both commands with Zig 0.14.0 and QEMU 8.2.2. The ELF domains were text `[0x80200000,0x80205000)`, rodata `[0x80205000,0x80206000)`, and writable `[0x80206000,0x8021f000)`; both machines exposed 32 actual leaf PTEs with zero user and zero writable-plus-executable leaves and retained the owned root at `0x80217000`. This does not prove U-mode, page-fault recovery, processes, syscalls, demand paging, a general VMM, or a Linux ABI.

## Bounded S→U→S round-trip commands (Batch 19)

- `python3 tools/verify-freestanding-riscv64-umode-round-trip.py --self-test` rejection-tests the distinct Batch 19 frame, copied-template ECALL relation, trusted supervisor trap-stack bounds, exact mixed-privilege raw leaves, alias L0 reuse, fence evidence, restored trap state, and contradiction paths.
- `python3 tools/verify-freestanding-riscv64-umode-round-trip.py` is the canonical Batch 19 execution lab. It executes two bounded real system-QEMU machines and independently proves SRET with SPP=0, real user RX instructions and RW/NX stack access, one cause-8 ECALL, register-only `sscratch` stack switching before stores, deliberate supervisor continuation, exactly two U leaves, zero W+X leaves, Batch 12–18 preservation, and exact 765-byte hosted/fake/machine Morphic equality.

Batch 19 executed the self-test and full lab with Zig 0.14.0 and QEMU 8.2.2. Both machines reused the existing four-page page-table hierarchy, installed only `0x80401000` U RX and `0x80402000` U RW/NX, trapped the copied template's ECALL at `0x8040100e` with cause 8 and SPP=0 on the dedicated supervisor-only trap stack, restored the canonical trap vector, and retained exact 765-byte Morphic equality. This is not a syscall ABI, process model, user ELF loader, safe user-copy facility, page-fault recovery, or Linux compatibility proof.

## Bounded ECALL service return commands (Batch 20)

- `python3 tools/verify-freestanding-riscv64-ecall-return.py --self-test` executes one bounded fixture and mutation-rejects framing/order, first/second/third trap counts, interrupt/cause/SPP state, ELF-derived service/resume/terminal PCs, user/trap-stack bounds and permissions, service inputs/result, actual prepared status, user result/sentinel/terminal marker, return counts, CSR/root/allocation drift, fence policy, and added/missing/changed/U/W+X leaves.
- `python3 tools/verify-freestanding-riscv64-ecall-return.py` builds and independently inspects the ELF, runs native and fake Morphic twice, executes two real system-QEMU machines, preserves the strict Batch 12–19 parser chain, and proves the fixed `0x20 + 0x19 -> 0x39` supervisor service, one SRET back to resumed U-mode, one terminal SRET to the ELF-derived S-mode continuation, actual zero-growth allocator/page-table snapshots, exact equality with the Batch 19 final leaf set and user PAs, exactly two U leaves, zero W+X leaves, CSR restoration, and exact 765-byte equality.

Batch 20 executed both repaired commands with Zig 0.14.0 and QEMU 8.2.2. Actual evidence showed allocator count `7 -> 7`, page-table count `4 -> 4`, identical Batch 19 and Batch 20 U-page PAs, one unchanged 36-leaf set, U=2, W+X=0, and the same trusted trap-frame address for both traps. It reuses the Batch 19 U RX code frame, U RW/NX stack frame, four-page hierarchy, and trusted supervisor stack. This is not a syscall table, Linux ABI, user-copy facility, process model, userspace ELF loader, or arbitrary-user-pointer proof.

Batch 21A compiler-executed `test-bounded-user-memory-transfer-plan`, `smoke-bounded-user-memory-transfer-plan`, agent doctor, and `python3 tools/developer-command.py validate-repository` successfully under Zig 0.14.0 after recording current unit and smoke evidence for all 54 modules; the run intentionally did not execute the Batch 18/19/20 real-QEMU labs.

### Batch 21B real user copy-IN

```text
python3 tools/verify-freestanding-riscv64-user-copy-in.py --self-test
python3 tools/verify-freestanding-riscv64-user-copy-in.py
```

The self-test mutation-checks the strict Batch 21B evidence parser. The full command builds the freestanding ELF, derives copied user-probe locations from its symbols, runs two independent `qemu-system-riscv64` machines, preserves the Batch 20 proof chain, and checks exact 765-byte Morphic equality.

Batch 21B repair validation executed both the rejection self-test and full two-machine QEMU verifier successfully under Zig 0.14.0, proving two traps per machine, U=2, W+X=0, and exact 765-byte Morphic equality; the complete repository validation also passed 326/326 build steps and 216/216 tests.

### Batch 21C bounded real user-memory transfer

- `python3 tools/verify-freestanding-riscv64-user-memory-transfer.py --self-test` builds and executes one real bounded system-QEMU fixture, validates the completed Batch 21 evidence chain, and mutation-rejects the copy-OUT, permission-rejection, atomic-rejection, conservation, permission, and policy evidence.
- `python3 tools/verify-freestanding-riscv64-user-memory-transfer.py` is the canonical Batch 21C execution lab. It executes two independent `qemu-system-riscv64` machines, preserves the strict Batch 21B parser chain, proves the exact 16-byte `kernel-to-user!!` write through planner-produced physical segments with SUM clear, rejects the real U RX page as `NotWritable`, rejects the writable-prefix/unmapped-suffix range as `Unmapped` without prefix mutation, derives U=2 and W+X=0 from unchanged leaves, and requires exact 765-byte hosted/fake/machine Morphic equality.

Batch 21C executed both commands under Zig 0.14.0 and QEMU 8.2.2. Each machine observed four expected U-mode ECALL traps, allocator and page-table counts remained 7 and 4 respectively, and the active `satp`, root, PTEs, user physical frames, and two-leaf user permission truth remained unchanged. This is a bounded native user-memory boundary proof, not Linux `copy_to_user`, EFAULT/fault fixup, concurrent-remapping safety, a syscall ABI, process model, ELF loader, VFS, or Linux compatibility.

PR #43 review repair re-executed the Batch 21C self-test, two-machine verifier, and complete 326/326-step, 216/216-test repository validation under Zig 0.14.0 and QEMU 8.2.2. The verifier now consumes actual cause, trusted trap-frame, prepared-status, and planner-segment evidence and cross-checks Batch 21C trap-vector, SATP, and root truth against Batch 21B.

PR #43 final review repair made both Batch 21C verifier modes append one bounded `LOCATIONS` then `MINIMUS` handoff after their ordinary output. Controlled invocation failure was also executed to confirm `FAIL`, actionable next-command output, and preservation of exit status 2.

## Batch 22A bounded ELF64 load planning

`zig build test-bounded-elf64-load-plan` runs the deterministic positive and rejection matrix for static RV64 ELF acceptance and failure-atomic PT_LOAD planning. `zig build smoke-bounded-elf64-load-plan` verifies the external named import. Batch 22A ran both successfully under Zig 0.14.0; it did not execute an ELF or require system QEMU. The complete validation record is `docs/reports/AGENTIC_SNOWBALL_BATCH_22A.md`.

PR #44 final Batch 22A merge-gate repair added deterministic planner rejection for ELF write-without-read permissions and checked `e_entry` conversion boundaries; the focused planner/parser stack and complete repository validation were rerun under Zig 0.14.0. This remains load planning only and does not execute an ELF.

## First real RV64 userspace ELF execution (Batch 22B)

- `zig build install-userspace-rv64-elf --prefix PATH` separately builds and installs the stripped, static, one-PT_LOAD RV64 ET_EXEC fixture at `PATH/bin/userspace-elf-rv64`.
- `python3 tools/verify-freestanding-riscv64-userspace-elf.py --self-test` runs one real-QEMU fixture and mutation-rejects the artifact, plan, byte-copy, entry, fence, trap, marker, resource, SATP, and PTE proof relationships.
- `python3 tools/verify-freestanding-riscv64-userspace-elf.py` is the strict Batch 22B lab. It independently parses the exact guest ELF embedded through the build graph, composes the Batch 21C parser, runs two real system-QEMU machines, and requires ELF-to-plan-to-loaded-byte-to-U-mode-trap agreement plus unchanged safety and Morphic truth.

PR #45 merge-gate repair directly compared every planner-selected ELF source byte with its volatile loaded destination byte, regenerated all 55 validation-evidence records and the seven deterministic agent indexes, and reran `zig build check`, the strict one-QEMU mutation self-test, the strict two-QEMU verifier, and the complete 330/330-step, 225/225-test repository validation successfully under Zig 0.14.0 and QEMU 8.2.2.

## First writable RV64 userspace ELF data/BSS proof (Batch 23)

- `zig build install-userspace-rv64-data-bss-elf --prefix PATH` separately builds and installs the static two-`PT_LOAD` RV64 ET_EXEC fixture at `PATH/bin/userspace-elf-rv64-data-bss`; its image has one R-X code segment and one initialized RW- segment with a non-empty BSS tail.
- `python3 tools/verify-freestanding-riscv64-userspace-elf-data-bss.py --self-test` executes one real QEMU fixture and mutation-rejects the initialized-byte, BSS-zero, RW/NX, mutation, entry/trap, resource-accounting, and artifact/plan proof relationships.
- `python3 tools/verify-freestanding-riscv64-userspace-elf-data-bss.py` is the strict Batch 23 lab. It independently inspects the exact two-segment guest artifact, composes the unchanged Batch 22B parser, runs two independent real system-QEMU machines, and requires exact writable-data/BSS/mutation agreement plus unchanged Morphic equality.

Batch 23 executed the historical Batch 22B self-test and two-QEMU verifier independently, then executed its own self-test and strict two-QEMU verifier under Zig 0.14.0 and QEMU 8.2.2. Each Batch 23 machine proved 8 initialized bytes, an 8-byte BSS tail zeroed before U-mode, mutation `0x23b55a5aa55ac33c` in the allocator-owned backing frame, three U leaves, zero W+X leaves, and the unchanged 765-byte Morphic artifact.

### Batch 24B real RV64 Linux initial-stack proof

- `zig build install-userspace-rv64-initial-stack-elf --prefix PATH` separately builds and installs the static two-`PT_LOAD` RV64 ET_EXEC startup-stack fixture at `PATH/bin/userspace-elf-rv64-initial-stack`.
- `python3 tools/verify-freestanding-riscv64-initial-stack.py --self-test` runs one real QEMU machine and mutation-rejects exact startup image, planner-derived SP, stack permission, trap, and marker relationships while composing the Batch 23 proof.
- `python3 tools/verify-freestanding-riscv64-initial-stack.py` runs two independent real system-QEMU machines, independently reconstructs and byte-compares the frozen Linux-style stack, verifies ELF/entry/ECALL/U-mode/PTE evidence, preserves Batch 23 and Morphic equality, and emits the canonical Batch 24B handoff.

Batch 24B executed the project-53/54/55 focused regressions, Batch 23 strict self-test and two-QEMU proof, its mutation self-test and strict two-QEMU proof under Zig 0.14.0 and QEMU 8.2.2. Both machines used planner-derived `SP=0x80402f50`, independently parsed the exact 176-byte image, returned through the unique ECALL, retained three U leaves and zero W+X leaves, and preserved the 765-byte Morphic artifact.

### Batch 25A Morphic operation boundary and Linux/RV64 syscalls

- `zig build install-userspace-rv64-linux-syscalls-elf --prefix PATH` builds and installs the raw two-segment RV64 Linux syscall fixture at `PATH/bin/userspace-elf-rv64-linux-syscalls`.
- `python3 tools/verify-freestanding-riscv64-linux-syscalls.py --self-test` runs one real QEMU machine, composes the Batch 24B strict parser, and rejects decisive Linux/semantic/event/PC/result/message/PTE mutations.
- `python3 tools/verify-freestanding-riscv64-linux-syscalls.py` runs two independent QEMU machines, independently inspects the exact ELF and five ECALL sites, verifies four exact `sepc + 4` returns plus terminal `exit_group`, exact write bytes and negative errno results, inherited Batch 24B truth, unchanged resource/mapping evidence, and Morphic equality.

Batch 25A executed the semantic-operation unit/smoke tests, project 53/54/55 regressions, Batch 24B one- and two-QEMU proofs, its mutation self-test and strict two-QEMU proof under Zig 0.14.0 and QEMU 8.2.2. The raw trap-entry repair explicitly aligns `.text.user_service_trap` to the four-byte `stvec.BASE` requirement.

### Batch 25B bounded resource table and Linux FD lifecycle

- `python3 tools/verify-freestanding-riscv64-linux-fd-lifecycle.py --self-test` runs one real QEMU machine and rejects decisive descriptor allocation, alias lifetime, EFAULT atomicity, event, result, resource-count, `sepc + 4`, and inherited process-start mutations.
- `python3 tools/verify-freestanding-riscv64-linux-fd-lifecycle.py` runs two independent QEMU machines and proves the 15-ECALL raw RV64 ELF path, 14 exact returns, terminal `exit_group`, deterministic stdin, real fd 0/1/2 bindings, `dup`/`close` alias lifetime, EBADF/EFAULT/ENOSYS, unchanged mappings, W+X=0, and hosted/fake/machine Morphic equality.

Batch 25B executed both verifier modes successfully with Zig 0.14.0 and QEMU 8.2.2. Linux UAPI constants were checked from the installed kernel UAPI headers before implementation. The generation-preservation repair forces machine stdin into reused slot generation 2 and requires the full generation-bearing semantic identity in focused smoke and both QEMU proof modes.

### Batch 26 capacity and dynamic-ELF repair

- `PYTHONDONTWRITEBYTECODE=1 python3 tools/check-bounded-filesystem-capacity.py` is the focused compile-fail regression for project 58. It requires Zig 0.14.0 to reject both a zero object capacity and a capacity larger than the complete `u16` `ObjectId` namespace.
- `zig build test-bounded-elf64-load-plan test-bounded-address-space-exec-image` exercises the preserved strict static ELF policy and the distinct dynamic `ET_DYN`/`PT_INTERP` interpreter handoff. The handoff owns the interpreter path and performs no relocation.

Batch 26 PR #53 synchronization regenerated the two affected port contracts, all canonical textual indexes, and complete unit/smoke validation evidence; `zig build check --summary all` and `python3 tools/developer-command.py validate-repository` then passed under Zig 0.14.0 for all 60 contracted modules.
