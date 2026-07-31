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
- `cc.threshold_warn` / `cc.threshold_fail`: CC thresholds
- `cog.nesting_penalty`: per-nesting penalty
- `cog.threshold_warn` / `cog.threshold_fail`: C-COG thresholds
- `parser.parser_mode`: `fast`, `balanced`, or `thorough`
- `parser.max_expected_errors_per_100_lines`: parse tolerance
- `report.formats`: `json`, `csv`
- `report.output_path`: JSON output path
- `report.csv_output_path`: CSV output path
- `report.auto_export`: auto write after analysis
- `report.annotate_editor`: enable/disable editor warnings
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
godot --headless --script cli/ci_test.gd -- --project-path . --output report.json --csv-output report.csv
```

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
