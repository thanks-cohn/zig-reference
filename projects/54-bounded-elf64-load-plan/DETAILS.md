# Bounded ELF64 Load Plan — Integration Contract

## Selection
Use `@import("bounded-elf64-load-plan")` when bounded ELF bytes must be accepted for the first static RV64 userspace subset and converted to an owned plan. Reject this module for dynamic linking, relocation, mapping, copying, or U-mode entry.

## Contract
`plan(capacity, bytes)` reuses `elf64-file-header-parser.parse` and `elf64-program-header-parser.parseTable`. It accepts ELF64, little endian, version 1, `ET_EXEC`, machine 243, at most 64 program headers, and at least one `PT_LOAD`. Dynamic, interpreter, TLS, shared-library, and unknown rows are rejected; null, note, and program-header rows are ignored.

Every admitted row has a bounded file range, `p_filesz <= p_memsz`, a checked virtual half-open range, coherent offset/address congruence for alignment greater than one, neither W+X nor W without R, and no overlap with another admitted row. The entry is checked into the guest-address backing type, copied from `e_entry`, and must be contained by an executable admitted range. An unrepresentable entry returns `EntryOutOfRange`; W without R returns `WriteWithoutRead`. Empty and boundary-touching half-open ranges do not overlap.

The returned `LoadPlan` owns fixed inline storage in program-header order. Each `SegmentPlan` exposes source and memory ranges, typed guest virtual start, file/memory/zero-fill counts, exact R/W/X truth, and alignment. Inputs are borrowed only during the call; no allocation or cleanup occurs. Because construction is local and returned only after all rows and entry truth validate, every error returns no partial usable plan.

## Environment and non-goals
The mechanism is deterministic, allocation-free, endian-aware, and usable hosted or freestanding. It is not thread-sensitive; ELF addresses that do not fit the `usize`-backed address/range types are rejected deterministically. It performs no page allocation, mapping, byte copy, BSS zeroing, cache/TLB fence, privilege transition, syscall, relocation, interpreter, or execution.

## Dynamic interpreter handoff

`planDynamic` is a separate, explicit policy surface for RV64 `ET_EXEC`/`ET_DYN` images. It owns and validates a single NUL-terminated `PT_INTERP` pathname and tolerates `PT_DYNAMIC` as interpreter work; it never relocates bytes. The original `plan` contract remains the narrow static `ET_EXEC` proof and continues to reject `PT_INTERP`, `PT_DYNAMIC`, and non-executable object types.
