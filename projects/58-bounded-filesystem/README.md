# Bounded filesystem

An allocation-free, Linux-independent object tree for deterministic files and directories. Paths resolve from an explicit directory capability; byte reads never contain file descriptors, errno values, or syscall flags.

See [DETAILS.md](DETAILS.md) and [MASTERY.md](MASTERY.md).

See [port.js](port.js) for Zig-version migration constraints.

The compile-time `object_capacity` must include the root object and must fit the `ObjectId` namespace.
