# Mastery: Bounded ELF64 Load Planning

The key separation is interpretation before mutation: first prove every ELF fact, then let a later machine layer consume an immutable plan. A valid early PT_LOAD cannot authorize side effects because a later row can still invalidate the entire file.

## Invariants
- Parser output is reused rather than decoded again.
- Source and destination ranges are checked half-open ranges.
- `zero_fill_byte_count = memory_byte_count - file_byte_count`.
- Segment order is program-header order.
- W+X, W without R, and overlapping admitted memory ranges are rejected.
- `e_entry` is checked before conversion to the guest-address backing type.
- `e_entry` is the ELF header value and lies inside executable admitted memory.

## Reasoning exercises
1. Explain why an entry at `memory.end` is rejected.
2. Explain why boundary-touching ranges are safe under half-open semantics.
3. Add a rejecting fixture after an otherwise valid row and verify that no value can be observed.
4. Identify which operations Batch 22B must perform without changing this module's interpretation policy.

## Static proof versus dynamic handoff

Do not weaken `plan` to accept dynamic inputs. `planDynamic` is the adjacent policy: it validates load segments, owns `PT_INTERP`, and leaves `PT_DYNAMIC` and every relocation to the userspace interpreter.
