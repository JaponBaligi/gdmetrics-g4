# Schema Contract (v1.0)

Frozen as of **gdmetrics 1.0.0 (PROUD)**. Report JSON `"version"` is `"1.0"`.

Breaking changes to this contract require a Pride **PROUD** bump to **2.0.0** (see [BREAKING_CHANGES.md](BREAKING_CHANGES.md)).

## JSON report shape

Produced by `report_generator.generate_report()` (Godot 3/4 variants).

| Field | Type | Notes |
|-------|------|--------|
| `version` | string | Always `"1.0"` for this contract |
| `timestamp` | string | ISO-like datetime from engine |
| `project` | object | Aggregate run metadata |
| `worst_offenders` | object | Top files by metric |
| `files` | array | Per-file results |
| `errors` | array | Project-level error strings |
| `telemetry` | object | Optional; only if `telemetry.enable_anonymous_reporting` |

### `project`

| Field | Type |
|-------|------|
| `total_files` | int |
| `successful_files` | int |
| `failed_files` | int |
| `totals` | `{ "cc": int, "cog": int }` |
| `averages` | `{ "cc": float, "cog": float, "confidence": float }` |
| `error_summary` | object (code → count) |
| `error_severity_summary` | object (severity → count) |
| `total_errors` | int |
| `performance` | object (optional profiling keys) |

### `worst_offenders`

| Field | Type |
|-------|------|
| `cc` | array of `{ "file", "cc", "confidence" }` |
| `cog` | array of `{ "file", "cog", "confidence" }` |

### `files[]` entry

| Field | Type | Notes |
|-------|------|--------|
| `file` | string | Path |
| `success` | bool | |
| `cc` | int | File total CC |
| `cog` | int | File total C-COG |
| `confidence` | float | |
| `cc_breakdown` | object | |
| `cog_breakdown` | object | |
| `errors` | array | |
| `max_nesting_depth` | int | |
| `match_arm_count` | int | |
| `lambda_count` | int | |
| `loc_code` | int | |
| `max_params` | int | |
| `functions` | array | Present when `success` |
| `classes` | array | Present when `success` |

### `files[].functions[]` entry

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | |
| `type` | string | e.g. function kind |
| `start_line` | int | |
| `end_line` | int | |
| `parameters` | int | Parameter count |
| `return_type` | string | |
| `cc` | int | Present when computed |
| `cog` | int | Present when computed |

Consumers should treat `cc` and `cog` as the stable per-function metrics under v1.

## Config keys (v1)

Root object in `complexity_config.json` (see `complexity_config.example.json`).

| Key | Purpose |
|-----|---------|
| `include` | Glob patterns of files to analyze |
| `exclude` | Glob patterns to skip |
| `cc` | `threshold_warn`, `threshold_fail` (ints) |
| `cog` | `threshold_warn`, `threshold_fail` (ints) |
| `structural` | `nesting_warn`/`fail`, `params_warn`/`fail`, `loc_warn`/`fail` |
| `parser` | `parser_mode`, `confidence_weights` |
| `report` | Formats and output paths (see below) |
| `performance` | Caching / profiling |
| `telemetry` | Anonymous reporting toggle |
| `logging` | Console/file log settings |

### `report` (stable paths)

| Key | Default (example) | Notes |
|-----|-------------------|--------|
| `formats` | `["json","csv","html"]` | |
| `output_path` | `res://complexity_report.json` | JSON |
| `csv_output_path` | `res://complexity_report.csv` | CSV |
| `html_output_path` | `res://complexity_report.html` | HTML |
| `history_path` | `complexity_history.jsonl` | Append-only history |
| `auto_export` | `false` | Editor auto-export after analysis |

CLI flags may override output/history paths; the keys above remain the config contract.

## Stability rule

- Additive optional fields may appear in DEFAULT releases without a PROUD bump.
- Renames, removals, or semantic changes to listed keys/fields require **2.0.0**.
