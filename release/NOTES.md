## GDMetrics for Godot 4 — v0.3.0

Pride Versioning **DEFAULT** release (`PROUD.DEFAULT.SHAME`). Early / pre-stable until 1.0.0.

### Highlights
- **HTML report**: self-contained HTML with totals, top offenders, per-file table, and SVG C-COG bars (`--html-output` / Export HTML)
- **Dock secondary metrics**: Nest, Params, LOC columns on file rows
- **Structural gates**: `structural` config keys for NEST / PARAMS / LOC warn+fail thresholds
- **JSON per-function CC**: each function entry includes `"cc"` alongside `"cog"`
- CI threshold gates for CC / C-COG / structural metrics (exit code `1` on fail)

### Install
1. Download `gdmetrics-v0.3.0.zip`
2. Copy `addons/gdscript_complexity/` and `cli/` into your Godot 4 project
3. Project → Project Settings → Plugins → enable **GDScript Complexity Analyzer**
4. Optional: copy `examples/github-actions/complexity-check.yml` into `.github/workflows/`

### CLI
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv --html-output report.html
```

### Docs
See `README.md`, `docs/USER_GUIDE.md`, `docs/DISTRIBUTION.md`, and `docs/COMPATIBILITY.md` in the zip.
