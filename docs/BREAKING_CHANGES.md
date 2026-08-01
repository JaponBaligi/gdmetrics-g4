# Breaking Changes Log

This document tracks breaking changes by release.

## 0.2.0

- CLI consumer entrypoint is now `cli/analyze_project.gd` (preferred). `tests/ci_test.gd` remains as a thin wrapper.
- Analysis now exits with code `1` when any function meets or exceeds `cc.threshold_fail` or `cog.threshold_fail` (unless `--no-fail-on-threshold`).
- Exit code `2` is reserved for tool/path/write errors (previously many of these returned `1`).
- Config JSON numeric thresholds are accepted as floats (Godot JSON parse) and coerced to ints — previously `is int` checks silently ignored JSON numbers.

## Unreleased

- None
