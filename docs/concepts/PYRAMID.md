# The Zig Reference Pyramid

`zig-reference` is cumulative. Each project introduces only a small number of new ideas, then becomes usable knowledge for the projects above it.

The repository does not begin with a server, database, or virtual machine. It begins with the smallest structure that can state and defend an invariant.

## Design rule

Every new level must answer three questions:

1. What new problem is introduced here?
2. Which lower-level ideas does the solution reuse?
3. Which higher-level projects will depend on this idea?

A project should not hide an important mechanism merely to shorten the code. The implementation must remain small enough to study, but complete enough to teach habits that survive production use.

## Current foundation

```text
04  bounded byte reader   borrowed input, cursor safety, sub-readers
03  fixed bit set         compact state, masks, padding invariants
02  ring buffer           FIFO order and wrapped indexing
01  dynamic array         allocator ownership and failure-atomic growth
00  fixed vector          capacity, initialized storage, slices, errors
```

## New boundary layer

Modules 29–38 add parser transactions and TLV structure, owned bytes and object pools, typed physical memory allocation, and ELF64 header/segment parsing. Each imports the lower guarantee rather than restating it.

## Planned ascent

```text
                         12  compiler / virtual machine
                      11  key-value database
                   10  HTTP server and protocol state
                09  thread pool and work queues
             08  process runner and pipelines
          07  binary formats and validated parsers
       06  hash table and indexed storage
    05  stack, tokenizer, and expression evaluator
00-04  reusable foundation
```

The bit set forms an additional branch toward bitmap allocation, page tracking, permissions, and freestanding systems. The bounded reader forms the direct base for archives, images, executable formats, and network protocols.

## How later projects reuse the base

- The expression evaluator reuses dynamic storage and explicit errors.
- The hash table reuses owned storage, growth, failure atomicity, and invalidation rules.
- Bitmap allocators reuse the bit set's logical-versus-physical representation.
- Parsers reuse slices, bounded cursor movement, sub-readers, and explicit errors.
- Work queues reuse ring-buffer mechanics and add synchronization.
- Databases reuse dynamic storage, parsing, checksums, and failure-atomic replacement.
- Servers reuse bounded readers, state machines, queues, and owned resources.
- Hypervisors can reuse fixed storage, bitmaps, bounded executable parsing, and explicit lifecycle state.

## Teaching standard

Every project includes:

- **What it is**
- **Why people build it**
- **The deceptively easy C version**
- **Where that version begins to decay**
- **The invariants**
- **The Zig design**
- **Failure-path tests**
- **Reference invalidation rules**
- **Exercises that extend rather than rewrite the design**
- **A `docs/standards/MASTERY.md` guide**

The objective is cumulative understanding: each new project should feel like the next necessary consequence of the previous one.
