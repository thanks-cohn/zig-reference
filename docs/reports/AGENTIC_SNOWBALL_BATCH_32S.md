# Agentic Snowball Batch 32S handoff

## Persistence boundary and inherited defects

Work began on branch `work` from `a48a88d` (the Batch 32S plan, immediately
after PR #94 merge `7d41ab9`) on 2026-08-15 UTC. The opening bootstrap passed;
doctor confirmed Zig 0.14.0 but reported the inherited missing `.venv`.

PR #94 assigned `newfstatat` inode identity from the JSON `"path"` token while
open plus `fstat` used the resolved object's manifest-row offset. It also named
an ordinary live trace `ZIGREF_LINUX_MMAP_REJECT`, although that spelling was
neither a stable hyphenated repository diagnostic nor indexed repair guidance.

## Repairs and permanent proof

`bounded_namespace_lookup.resolveFinalObject` now exposes the exact final
object for no-follow metadata. Followed stat continues through `resolve`, so
both followed `newfstatat` and open-plus-`fstat` encode
`manifest_offset + 1`; a no-follow symlink instead retains its own manifest
identity. The resolver regression proves direct-target and followed-symlink
identity equality and distinct no-follow symlink identity. Both stat paths use
the existing checked 128-byte Linux/RV64 encoder/copyout.

The rejection output is now plainly `LINUX_MMAP_REJECT`. It remains a compact
six-argument causal trace and no longer masquerades as an authored
`ZIGREF-*` diagnostic.

## File-backed MAP_PRIVATE progress

The new focused planner accepts only MAP_PRIVATE, page-aligned file offsets,
valid R/W/X bits, and W+X=0. It checks arithmetic and the authoritative file
extent, rounds bounded backing to pages, copies the available immutable source
range into private pages, and zeroes the final page tail. Runtime integration
resolves the descriptor through binding/resource ownership, accepts only the
namespace regular backend, preserves descriptor state/file position, reserves
the range before mapping, installs requested PTE permissions, rolls back
partially installed leaves, and commits backing ownership only after success.
Tests prove exact offset bytes, tail zeroing, source immutability, RX without
W+X, invalid mapping class/alignment/range, and W+X rejection. Existing binding
resolution tests retain permanent EBADF/ownership-conservation coverage.

## Exact Alpine and QEMU evidence

The canonical acquisition rebuilt 517 objects and 7,069,903 regular bytes.
Namespace data SHA-256 was
`7672a8c49fbd75071a6390a55e227927254afe1eabdad969315414332e5b989b`;
BusyBox was `4567ce8a67afd045a9be46745236cf6fca0347f70871a2492c94c166eada856e`;
musl was `f65dfa1e845af4d8c57f5274a8abac7a8c150372b014fb413e44f4cc70050de1`.
The exact commands were:

```text
PYTHONDONTWRITEBYTECODE=1 python3 tools/pressure-real-rv64-alpine-minirootfs.py --artifact-only --namespace-output-dir /tmp/zigref-namespace
zig build install-freestanding-riscv64-morphic-runtime -Dexternal-rv64-namespace-manifest=/tmp/zigref-namespace/namespace.json -Dexternal-rv64-namespace-data=/tmp/zigref-namespace/namespace.data -Dexternal-rv64-argv0=/bin/sh -Dexternal-rv64-live-console-input=true --prefix /tmp/alpine-machine
{ sleep 5; printf '/sbin/apk --version\n'; } | timeout 20s qemu-system-riscv64 -machine virt -nographic -bios default -kernel /tmp/alpine-machine/bin/morphic-freestanding-riscv64
```

QEMU 8.2.2 proved file-backed mmap is now dispatched. The first libcrypto
mapping fails with `Out of memory` at the explicit 320-page prepared/private
backing bound (the observed 0x3b6000 request alone needs 950 pages). The smaller
libapk initial mapping crosses; its next request is a fixed private file mapping
(`address=0x3d000 length=0x3000 protection=3 flags=0x12 fd=3 offset=0x28000`),
which remains deliberately rejected and becomes downstream of the earlier
libcrypto capacity failure. `libz.so.1` is present as a relative symlink and
still reports ENOENT, also downstream.

`/sbin/apk --version` did **not** succeed; `--help` and `info` were not reached.
The playable-shell regression was not rerun before persistence; focused recipe
tests and the namespace-backed freestanding build did pass.

## Validation, files, and one next pressure

Passed: focused namespace lookup tests (5/5), file mmap tests (2/2), the complete
Morphic recipe step, formatting, namespace acquisition, and the freestanding
build. Two corrected delayed-input QEMU retries preserved the failure above.

Changed files are `build.zig`, `COMMANDS.md`, this report, and
`recipes/run-hosted-morphic-runtime/src/{bounded_namespace_lookup.zig,
freestanding_riscv64.zig,linux_rv64_file_mmap.zig}`. Final commit SHA is the
commit containing this report (obtain with `git rev-parse HEAD`).

**Exactly one next causal blocker:** enlarge or separately provision the
bounded private file-mapping backing enough to satisfy the observed 950-page
libcrypto mapping without overlapping caller-artifact transport, then rerun
the unchanged command before addressing fixed mappings or relative symlinks.
