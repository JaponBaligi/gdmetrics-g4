## GDMetrics for Godot 4 — v0.4.0

Pride Versioning **DEFAULT** release (`PROUD.DEFAULT.SHAME`). Early / pre-stable until 1.0.0.

### Highlights
- **Append-only history**: successful analyses append a JSON line to `complexity_history.jsonl` (configurable via `report.history_path`)
- **CLI diff**: `--diff` prints Δ totals/averages and fail_count vs previous history line or `--baseline`; `--fail-on-diff-regression` exits `1` when `avg_cog` or `fail_count` increases
- **CI matrix**: GitHub Actions tests on Godot 4.0.4 and 4.2.0

### Install
1. Download `gdmetrics-v0.4.0.zip`
2. Copy `addons/gdscript_complexity/` and `cli/` into your Godot 4 project
3. Project → Project Settings → Plugins → enable **GDScript Complexity Analyzer**
4. Optional: copy `examples/github-actions/complexity-check.yml` into `.github/workflows/`

### CLI
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv --html-output report.html

# Trend vs previous history line
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --diff

# Fail CI on avg_cog / fail_count regression vs baseline snapshot
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --baseline baseline.jsonl --fail-on-diff-regression
```

### Docs
See `README.md`, `docs/USER_GUIDE.md`, `docs/DISTRIBUTION.md`, and `docs/COMPATIBILITY.md` in the zip.
