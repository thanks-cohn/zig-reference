## Summary

Describe the change and the boundary it affects.

## Why

Explain why the change is needed and which existing capability, plan, issue, or failure motivated it.

## Evidence / behavior established

State only relationships actually established by the implementation and executed validation.

- [ ] Public/API behavior is described precisely.
- [ ] Machine-specific claims identify the real execution/evidence boundary.
- [ ] Known limitations and nonclaims remain explicit.

## Validation

List the exact commands executed and their results.

```text
command — PASS / FAIL / BLOCKED
```

- [ ] Focused validation completed where applicable.
- [ ] `zig build check` completed, or the exact blocker is stated.
- [ ] `python3 tools/developer-command.py validate-repository` completed, or the exact blocker is stated.
- [ ] `COMMANDS.md` remains current when the runnable command surface changed.
- [ ] Generated indexes/evidence were regenerated or checked when canonical inputs changed.

## Reuse / impact

- [ ] Existing repository capabilities were queried before adding a new primitive.
- [ ] Shared-module impact was inspected when changing a foundation.
- [ ] No compatible canonical implementation was duplicated unnecessarily.

## Handoff

For a substantial batch or composition change, include the repository's normal Snowball Yield / LOCATIONS / MINIMUS handoff and the next actionable pressure.
