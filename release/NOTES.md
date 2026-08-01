## GDMetrics for Godot 4 — v1.0.0

Pride Versioning **PROUD** release (`1.0.0`). Stable report/config contract.

### Highlights
- **Schema freeze**: JSON report `"version": "1.0"` and config keys documented in `docs/SCHEMA.md`
- **Shared core**: calculators, detectors, gates, history, errors, logger under `addons/gdscript_complexity/src/core/` (canonical in g4; sync with `scripts/sync_core.ps1`)
- **Editor annotations**: after Analyze Project, functions at or above `cc`/`cog` `threshold_fail` get ScriptEditor annotations via `add_error_annotation` (Godot 4.2+)
- Prior DEFAULT features retained: HTML/CSV/JSON, history JSONL, CLI `--diff` / `--fail-on-diff-regression`, structural gates

### Install
1. Download `gdmetrics-v1.0.0.zip`
2. Copy `addons/gdscript_complexity/` and `cli/` into your Godot 4 project
3. Project → Project Settings → Plugins → enable **GDScript Complexity Analyzer**
4. Optional: copy `examples/github-actions/complexity-check.yml` into `.github/workflows/`

### CLI
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv --html-output report.html

godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --diff

godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --baseline baseline.jsonl --fail-on-diff-regression
```

### Docs
See `README.md`, `docs/SCHEMA.md`, `docs/USER_GUIDE.md`, `docs/DISTRIBUTION.md`, and `docs/COMPATIBILITY.md`.

### Breaking
See `docs/BREAKING_CHANGES.md` (1.0.0): core load paths moved to `src/core/`; schema is frozen until 2.0.0.
