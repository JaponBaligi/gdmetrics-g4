# User Guide

## Installation

This repository is for **Godot 4.x**. For Godot 3.x, see [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3).

```bash
git clone https://github.com/JaponBaligi/gdmetrics-g4
cd gdmetrics-g4
```

### Install the plugin
1. Copy `addons/gdscript_complexity` into your project's `addons/` directory.
2. Open the project in Godot.
3. Go to **Project > Project Settings > Plugins**.
4. Enable **GDScript Complexity Analyzer**.

## Configuration

Create `complexity_config.json` in the project root (or copy `complexity_config.example.json`).

### Common fields
- `include`: file patterns to analyze (default: `["res://**/*.gd"]`)
- `exclude`: file patterns to skip
- `cc.count_logical_operators`: include logical operators in CC
- `cc.threshold_warn` / `cc.threshold_fail`: CC thresholds (`threshold_fail` → CLI exit 1)
- `cog.nesting_penalty`: per-nesting penalty
- `cog.threshold_warn` / `cog.threshold_fail`: C-COG thresholds (`threshold_fail` → CLI exit 1)
- `parser.parser_mode`: `fast`, `balanced`, or `thorough`
- `parser.max_expected_errors_per_100_lines`: parse tolerance
- `report.formats`: `json`, `csv`
- `report.output_path`: JSON output path
- `report.csv_output_path`: CSV output path
- `report.history_path`: append-only JSONL history path (default `complexity_history.jsonl`)
- `report.html_output_path`: HTML report path (default `res://complexity_report.html`)

Stable report/config contract: [SCHEMA.md](SCHEMA.md) (`"version": "1.0"`).
- `report.auto_export`: auto write after analysis
- `report.annotate_editor`: enable/disable editor warnings (default off)
- `report.churn_hotspots`: `auto` (default), `on`, or `off` — mark scary files that git recently touched
- `report.churn_since`: git `--since` window (default `90 days ago`)
- `report.god_complex_func_min`: how many warn-level functions make a large file “scary” (default `3`)

### Ignore / pin comments

On the line above a function, or trailing on the `func` line:

```gdscript
# gdmetrics:ignore
func legacy_mess():
	pass

# gdmetrics:pin
func keep_watching():
	pass
```

- **ignore** — still scored; hidden from Top fixes and fail counts
- **pin** — always shown in Top fixes (watch list)

HTML exports include a **What to fix next** section (same ranking as the dock) and **Big scary files** (god-script rollups; Hot = scary + recent git churn when available).

- `performance.enable_caching`: caching on/off
- `performance.cache_path`: cache directory
- `performance.incremental_analysis`: analyze only changed files

## Usage

### Editor
1. Open the dock panel (appears when the plugin is enabled).
2. Click **Analyze Project**.
3. Review file and function metrics.
4. Use **Configure** to edit thresholds and reporting options.

### CLI
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv
```

Each successful run appends one JSON line to `complexity_history.jsonl` (or `report.history_path` / `--history-path`).

Trend vs previous history line (informational):
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --diff
```

Compare to a snapshot and fail when `avg_cog` or `fail_count` increases:
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --baseline baseline.jsonl --fail-on-diff-regression
```

Exit codes: `0` ok, `1` threshold_fail breach or diff regression (with `--fail-on-diff-regression`), `2` tool error. See `docs/DISTRIBUTION.md`.

### Auto export
Enable `report.auto_export` and specify formats:
```json
{
  "report": {
    "formats": ["json", "csv"],
    "output_path": "res://complexity_report.json",
    "csv_output_path": "res://complexity_report.csv",
    "auto_export": true
  }
}
```

## Troubleshooting

- **No editor annotations**: If annotations are unavailable, the plugin logs warnings to the console.
- **CSV not generated**: Ensure `report.formats` includes `csv`, set `report.csv_output_path`, or pass `--csv-output` in CLI mode.
- **Files analyzed: 0**: Check `include`/`exclude` patterns and confirm the project contains `.gd` files under `res://`.
- **Stale results**: Disable caching (`performance.enable_caching = false`) or delete the cache directory.
- **Low confidence scores**: The parser is block-oriented and not a full AST; review the limitations in `README.md`.

## FAQ

- **Does it modify scripts?** No. It reads `.gd` files and writes reports.
- **Need Godot 3.x?** Use [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3).
- **Can I disable editor warnings?** Yes. Set `report.annotate_editor` to `false`.
