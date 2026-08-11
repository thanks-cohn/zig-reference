#!/usr/bin/env python3
"""Require the bounded filesystem's structural capacity rejections."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "zero_capacity.zig": "object_capacity must include the root object",
    "object_id_overflow.zig": "object_capacity exceeds the ObjectId namespace",
}
for fixture, expected in CASES.items():
    command = [
        "zig", "test", "--dep", "bounded-filesystem",
        f"-Mroot={ROOT / 'projects/58-bounded-filesystem/tests/compile_fail' / fixture}",
        f"-Mbounded-filesystem={ROOT / 'projects/58-bounded-filesystem/src/bounded_filesystem.zig'}",
    ]
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode == 0:
        raise SystemExit(f"{fixture}: unexpectedly compiled")
    if expected not in result.stdout:
        raise SystemExit(f"{fixture}: wrong compiler rejection\n{result.stdout}")
print("bounded filesystem capacity compile-fail: PASS (2/2)")
