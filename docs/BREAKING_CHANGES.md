# Breaking Changes Log

This document tracks breaking changes by release.

## 1.0.0

- **Schema freeze**: JSON report `"version": "1.0"` and config keys documented in [SCHEMA.md](SCHEMA.md) are now a stable v1 contract.
- Future breaking changes to report shape or listed config keys require Pride **PROUD 2.0.0**.
- Shared analysis modules live under `addons/gdscript_complexity/src/core/` (load paths changed from `src/<module>.gd` to `src/core/<module>.gd`). External scripts that `load()` those paths must update.

## 0.2.0

- CLI consumer entrypoint is now `cli/analyze_project.gd` (preferred). `tests/ci_test.gd` remains as a thin wrapper.
- Analysis now exits with code `1` when any function meets or exceeds `cc.threshold_fail` or `cog.threshold_fail` (unless `--no-fail-on-threshold`).
- Exit code `2` is reserved for tool/path/write errors (previously many of these returned `1`).
- Config JSON numeric thresholds are accepted as floats (Godot JSON parse) and coerced to ints — previously `is int` checks silently ignored JSON numbers.

## Unreleased

- None
