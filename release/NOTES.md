## GDMetrics for Godot 4 — v0.1.3

Early release / pre-stable. Breaking changes may still occur before v1.0.

### Highlights
- Match/`when` arms, lambdas, raw strings, `%Unique` / `&"…"` / `^"…"` / `@"…"`
- Godot 4 multiline regular `"…"` / `'…'` strings (engine-accepted newlines)
- Line-continuation and triple-string trail/`\` fixes shared with the g3 line
- External project host CLI (`tests/analyze_external.gd`)
- Edge-case fixtures + corpus validation against real Godot 4 projects (`D:\test-4`: 12/12, 0 soft token errors)

### Install
1. Download `gdmetrics-v0.1.3.zip`
2. Copy `addons/gdscript_complexity/` into your Godot 4 project
3. Project → Project Settings → Plugins → enable **GDScript Complexity Analyzer**

### Docs
See `README.md`, `docs/USER_GUIDE.md`, `docs/EDGE_CASES.md`, and `docs/COMPATIBILITY.md` in the zip.
