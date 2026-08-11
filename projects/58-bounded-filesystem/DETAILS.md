# Integration contract

Use `FileSystem(object_capacity, name_capacity, file_capacity)`. `create` copies names and file bytes into inline storage. `lookup` traverses slash-separated components from an explicit directory; `read` copies a bounded range. No allocation or global state occurs. Returned object pointers borrow the filesystem and are invalidated by filesystem movement or destruction. Mutation is not synchronized. All errors occur before mutation.

This is not a POSIX VFS: it has no links, mounts, permissions, deletion, mutation, descriptor offsets, or Linux ABI rules.

`FileSystem` rejects an `object_capacity` of zero at compilation because the root object always occupies identity zero. It also rejects capacities larger than the complete `u16` `ObjectId` namespace, preventing truncating `@enumFromInt` conversions.
