# Integration contract

Use `AddressSpace(capacity)` for deterministic map, protect, unmap, and access checks. Storage is inline and mutations are failure-atomic. Use `ExecPlan(segment_capacity, interp_capacity).prepare` to stage a main ELF and optional interpreter; project 54 validates both. The returned plan owns copied interpreter-path bytes and inline load plans. The plan derives PT_INTERP from validated main-image bytes; the caller resolves that exact path through its filesystem, builds the initial stack with project 55, maps pages with project 49, and commits only after complete validation.

This module does not decode Linux mmap/exec flags, allocate physical pages, mutate page tables, parse PT_INTERP from raw program headers, relocate ELF objects, or promise a stable ABI.
