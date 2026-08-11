# Agentic Snowball Batch 26 — file, memory, and execution inheritance gate

## Result

**BLOCKED with coherent reusable progress preserved.** The run established the permanent Linux-independent Gate A and Gate B/C/D planning substrates, but the checked-in state does **not** claim the required Batch 26 real RV64 `openat`/`mmap`/`execve`/`PT_INTERP` machine integration. The bounded execution window ended before that kernel/fixture/verifier integration could be implemented and proved. No acceptance test was weakened and no planner result is represented as machine evidence.

## Frozen architecture

```text
Linux fd/path/syscall/errno adapter (not yet wired for Batch 26)
  -> explicit directory capability + bounded-filesystem ObjectId
  -> project 57 generation-bearing ResourceRef (unchanged)
  -> caller-owned open-file offset

Linux mmap/mprotect/munmap adapter (not yet wired)
  -> bounded AddressSpace candidate
  -> project 49 Sv39 map/protect/unmap commit
  -> project 48 invalidation

execve pathname -> bounded filesystem bytes
  -> project 54 main ELF plan
  -> optional project 54 interpreter ELF plan
  -> project 59 staged replacement candidate
  -> project 55 initial stack
  -> atomic page-table/image commit
  -> interpreter entry when PT_INTERP is present
```

Linux identities remain at the compatibility edge. Module 58 contains no fd, errno, flag, syscall, or register identity. Module 59 contains no Linux flag/errno/syscall identity and rejects W+X before mutation. Project 57 remains the only intended generational resource identity.

## Internal gates

### Gate A — reusable substrate PASS; machine gate pending

Project 58 adds fixed-capacity root/directory/file objects, explicit start-directory traversal, absolute-root traversal, copied inline names/content, bounded offset reads, and validation-before-mutation. It deliberately leaves descriptor bindings and shared open-file offsets to higher layers so an object ID is not confused with a Linux fd or `ResourceRef`.

Focused unit and external-smoke tests pass. Missing: the real RV64 `openat` fixture, user-path copy through project 53, project 57 binding, ENOENT/EFAULT evidence, close/reuse generation evidence in the Batch 26 fixture, and independent mutations.

### Gate B — reusable state PASS; machine gate pending

Project 59 adds page-aligned non-overlapping map/protect/unmap state, access queries, deterministic fixed capacity, validation-before-mutation, and unconditional W+X rejection. Project 49 remains the real Sv39 mutation mechanism; project 59 does not duplicate page tables.

Focused unit and external-smoke tests pass. Missing: physical-page ownership orchestration and real U-mode `mmap`, `mprotect`, `munmap`, access-fault, and two-QEMU evidence.

### Gate C — staged planner present; machine gate pending

`ExecPlan.prepare` composes project 54 for a main image and validates the complete candidate before it can be committed. Static execution selects the main entry. Missing: filesystem-fed `execve`, old-image argv/envp copying, project 55 stack construction, atomic live replacement, descriptor inheritance proof, and program-A-to-program-B QEMU execution.

### Gate D — interpreter handoff invariant present; machine gate pending

When supplied an interpreter path and independently resolved interpreter bytes, `ExecPlan.prepare` validates both images and chooses the interpreter entry while retaining the main entry and copied interpreter pathname. It performs no relocation. Missing: raw PT_INTERP extraction, filesystem resolution, main/interpreter placement, auxv (`AT_ENTRY`, `AT_BASE`, `AT_PHDR` as justified), real interpreter fixture transfer, and mutation verifier.

## ABI subset and primary sources checked

No new Linux ABI constants were committed. Before future adapter wiring this run checked installed primary UAPI headers:

- `/usr/include/asm-generic/unistd.h`: RV64 generic syscall identities `openat=56`, `brk=214`, `munmap=215`, `execve=221`, `mprotect=226`, and `mmap=__NR3264_mmap`;
- `/usr/include/linux/fcntl.h`: `AT_FDCWD=-100`;
- `/usr/include/asm-generic/fcntl.h`: `O_RDONLY=0`;
- `/usr/include/asm-generic/mman-common.h` and `/usr/include/linux/mman.h`: `PROT_READ=1`, `PROT_WRITE=2`, `PROT_EXEC=4`, `MAP_PRIVATE=2`, and `MAP_ANONYMOUS=0x20`.

These observations are not an implementation or compatibility claim.

## Evidence and regressions

- Modules 58 and 59 unit and external-smoke commands passed under Zig 0.14.0.
- Strict schema/contract/catalog/build consistency passed for all 60 modules.
- Static port contracts and `ports.json` passed for all 60 modules after Node.js became available.
- The inherited Batch 25B verifier self-test rejected decisive mutations.
- The inherited Batch 25B two-QEMU proof passed: 15 ECALLs, 14 exact returning transitions, terminal status 37, stdin generation 2, U=3, W+X=0, and Morphic result 765.
- No Batch 26 QEMU evidence exists yet; therefore overall Batch 26 cannot be PASS.

## Failures and root-cause repairs

1. Agent doctor initially reported the repository `.venv` missing. The prescribed venv and requirements restored contract validation.
2. New contract templates initially lacked structured endpoints, fixed portability facts, and correct dependency shapes. Schema errors were repaired at canonical `details.json` sources and indexes regenerated.
3. The environment initially lacked Node.js and QEMU. Both were installed; port checks and inherited machine regressions then ran.
4. A candidate module name containing the token `process` was rejected by the static port-contract parser's executable-JavaScript guard. The module was renamed to the more precise `bounded-address-space-exec-image`; no guard was weakened.
5. The decisive remaining failure is missing Batch 26 machine orchestration, not a compiler or infrastructure failure. The exact continuation starts at `recordLinuxRv64Syscall` and `executeLinuxRv64Syscalls` in the freestanding recipe, but should first add a separate Batch 26 fixture and strict verifier rather than expanding the Batch 25B fixture in place.

## Maximum inheritance check

1. **QuirkM:** explicit directory capabilities/object IDs, bounded path traversal, inline file storage, mapping candidates, W+X policy, and staged executable/interpreter plans are Linux-independent.
2. **Wasm/WASI:** a WASI adapter can translate its own preopen/resource identities into project 58 object IDs and project 57 `ResourceRef`s, and can use project 59 mappings without Linux fds, paths, errno, or syscall numbers.
3. **musl/BusyBox/Alpine:** real open/read/seek/stat, anonymous/file mappings, exec replacement, initial-stack/auxv truth, and PT_INTERP handoff are direct prerequisites; only reusable lower mechanisms are now present.
4. **Python/Node/Clang/Wasmtime:** the same file, large mapping/protection, exec, and dynamic-loader mechanisms are prerequisites, followed by Batch 27 process/thread/futex/signal/poll surfaces.
5. **QEMU/TCG:** file resources and large mapping/protection lifecycles are directly reusable; mature threads, signals, poll, timers, and devices remain later pressure.
6. **Hypervisor:** explicit mapping state and project 57 identity can be reused for memory/VM resources, while Linux executable quirks must not enter the native VM model.
7. **Quarantined Linux quirks:** fd allocation, `AT_FDCWD`, pathname errno, open/mmap flags, negative errno, RV64 registers/syscall numbers, auxv tags, and PT_INTERP pathname policy remain outside modules 58/59.
8. **Next maximum-yield surface:** one strict real-machine Batch 26 fixture/verifier wiring `openat` + anonymous `mmap` + `execve` + PT_INTERP through these candidates and projects 49/53–57.

## Quirk Extraction

QuirkM should inherit typed directory roots, object IDs, bounded byte reads, mapping permissions, and atomic image candidates. It must not inherit Linux descriptor integers, `AT_FDCWD`, errno, mmap flags, syscall numbering, auxv tag policy, or PT_INTERP pathname conventions. Wasm should receive the same separation through its own resource adapter.

## Snowball Yield

- Existing modules reused: project 54 directly; projects 49, 53, 55, 57 remain the documented commit/integration path.
- New reusable mechanisms: two—bounded filesystem object world and bounded address-space/exec-image candidate world.
- New Linux-specific mechanism: none.
- Machine inheritance retained: Batch 25B two-QEMU generation-2 resource proof.
- Unmeasured: productivity and performance.
- Deferred, not claimed: all Batch 26 Linux/QEMU acceptance evidence.

## Explicit nonclaims

No Batch 26 Linux `openat`, mmap-family syscall, `execve`, PT_INTERP extraction, dynamic loader, relocation, complete VFS, POSIX filesystem, musl, BusyBox, Alpine, Python, Node, Clang, Wasmtime, QEMU, hypervisor, or KVM support is claimed. Module 59 is candidate state, not a physical-page allocator or page-table implementation. Module 58 has no deletion, links, mounts, metadata, directory enumeration, write/truncate, or concurrency.

## Continuation handoff

- Branch at report creation: `work`.
- Remaining blocker: bounded execution window; required machine fixture/kernel/verifier implementation is absent.
- Exact next command after implementation begins: `zig build test-bounded-filesystem test-bounded-address-space-exec-image && python3 tools/verify-freestanding-riscv64-linux-fd-lifecycle.py`.
- First source locations: Batch 25B syscall trap path and execution orchestration in `recipes/run-hosted-morphic-runtime/src/freestanding_riscv64.zig`; add a distinct Batch 26 userspace fixture and `tools/verify-freestanding-riscv64-file-memory-exec.py`.
- Push, PR, SHA, and CI state are recorded in the final task response after commit/delivery.

## LOCATIONS

- `file:///workspace/zig-reference/projects/58-bounded-filesystem/details.json`
- `file:///workspace/zig-reference/projects/58-bounded-filesystem/src/bounded_filesystem.zig`
- `file:///workspace/zig-reference/projects/59-bounded-address-space-exec-image/details.json`
- `file:///workspace/zig-reference/projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig`
- `file:///workspace/zig-reference/recipes/run-hosted-morphic-runtime/src/freestanding_riscv64.zig`
- `file:///workspace/zig-reference/docs/reports/AGENTIC_SNOWBALL_BATCH_26.md`

## MINIMUS

status: PARTIAL
command: Batch 26 file + memory + exec inheritance gate
summary: file_substrate=PASS mapping_candidate=PASS exec_candidate=PARTIAL pt_interp_candidate=PARTIAL machine_batch26=NOT_PROVED resource_generation=preserved W+X=0 inherited_qemu=PASS
next: add the distinct Batch 26 RV64 fixture/kernel adapter/verifier and run it twice under QEMU

## PR #52 review repair checkpoint (2026-08-11)

The two inherited review findings are repaired without weakening the static proof:

1. Project 54's original `plan` remains the narrow static RV64 `ET_EXEC` surface and still rejects `ET_DYN`, `PT_INTERP`, and `PT_DYNAMIC`. The adjacent `planDynamic` surface accepts RV64 `ET_EXEC`/`ET_DYN`, validates and owns a single `PT_INTERP` pathname, represents `PT_DYNAMIC` as userspace-interpreter work, and performs no relocation. Project 59 now derives the path from the main ELF, requires separately resolved interpreter bytes, accepts an `ET_DYN` interpreter through that policy, rejects a recursively interpreted interpreter, and selects the interpreter entry while retaining `main_entry`.
2. Project 58 now compile-time rejects `object_capacity == 0` and every capacity greater than the 65,536-value `u16` `ObjectId` namespace. Dedicated compile-fail fixtures require both exact structural rejections.

Focused unit tests exercise dynamic main/interpreter handoff, malformed `PT_INTERP`, missing interpreter bytes, and preservation of the static rejection. The capacity checker passed both compile-fail mutations. Machine Gate A-D work continues below; this checkpoint does not convert planner evidence into QEMU evidence.

## PR #53 synchronization repair (2026-08-11)

Canonical port-contract creation/formatting synchronized projects 54 and 59 with their accepted public surfaces; canonical port-index, repository-index, dependency-graph, and validation-evidence generators then refreshed all derived state. `zig build check --summary all` passed 74/74 steps and 30/30 agent-contract tests. `python3 tools/developer-command.py validate-repository` passed the complete 60-module repository pipeline under Zig 0.14.0, including unit, smoke, recipe, conformance, property, fuzz-smoke, and differential gates. No generated artifact was hand-edited.
