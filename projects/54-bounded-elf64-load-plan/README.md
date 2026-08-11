# Bounded ELF64 Load Plan

This module composes the canonical ELF64 file- and program-header parsers into an allocation-free, failure-atomic load plan. It accepts only little-endian static RV64 executable ELF files, preserves PT_LOAD permission truth, rejects W+X, write-without-read, and overlaps, checks entry conversion, and requires the header entry inside executable load memory.

It does not copy bytes, allocate memory, map pages, or execute an ELF. Use `zig build test-bounded-elf64-load-plan` and `zig build smoke-bounded-elf64-load-plan`.

Porting metadata for the Zig 0.14.0 baseline is in [`port.js`](port.js); it does not claim compatibility with later Zig versions.

For dynamic execution, use the separate `planDynamic` boundary. It represents `ET_DYN`, `PT_INTERP`, and `PT_DYNAMIC` handoff facts without performing relocation; `plan` intentionally remains the strict static subset.
