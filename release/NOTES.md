## GDMetrics for Godot 4 — v0.2.0

Pride Versioning **DEFAULT** release (`PROUD.DEFAULT.SHAME`). Early / pre-stable until 1.0.0.

### Highlights
- **CI threshold gates**: `cc.threshold_fail` / `cog.threshold_fail` return exit code `1` with a breach summary
- Consumer CLI: `cli/analyze_project.gd` (exit `0` / `1` / `2`)
- Release zip includes `cli/` and `examples/github-actions/`
- Drop-in GitHub Actions template for PR complexity gates
- Docs: Pride Versioning + distribution notes (`docs/DISTRIBUTION.md`)

### Install
1. Download `gdmetrics-v0.2.0.zip`
2. Copy `addons/gdscript_complexity/` and `cli/` into your Godot 4 project
3. Project → Project Settings → Plugins → enable **GDScript Complexity Analyzer**
4. Optional: copy `examples/github-actions/complexity-check.yml` into `.github/workflows/`

### CLI
```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv
```

### Docs
See `README.md`, `docs/USER_GUIDE.md`, `docs/DISTRIBUTION.md`, and `docs/COMPATIBILITY.md` in the zip.
