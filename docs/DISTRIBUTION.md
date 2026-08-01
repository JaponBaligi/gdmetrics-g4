# Distribution

## Channels

- **GitHub Releases** (primary): tagged `vPROUD.DEFAULT.SHAME` builds with a zip of the addon, CLI, examples, and docs.
- **itch.io** (mirror): same source package; no separate binaries.

## Versioning (Pride Versioning)

Versions follow [Pride Versioning](https://pridever.org/): **PROUD.DEFAULT.SHAME**.

| Segment | Meaning |
|--------|---------|
| PROUD | Bump when the release is something you are really proud of (`N.0.0`) |
| DEFAULT | Normal / okay feature release (`P.D.0`) |
| SHAME | Fix something too embarrassing to admit (`P.D.S+1`) |

Git tags use a `v` prefix (example: `v0.2.0`). `plugin.cfg` `version=` omits the `v`.

Ship **one** Pride version at a time: implement → CI → tag → GitHub Release → then start the next DEFAULT/PROUD slice.

**1.0.0 (PROUD)** freezes the JSON report and config contract documented in [SCHEMA.md](SCHEMA.md). Breaking schema/config changes require **2.0.0**.

## Package contents

Release zips include:

- `addons/gdscript_complexity/`
- `cli/` (including `analyze_project.gd`)
- `examples/github-actions/`
- `docs/` (including `SCHEMA.md`, `USER_GUIDE.md`, `DISTRIBUTION.md`), `README.md`, `LICENSE`
- `complexity_config.example.json`
- `scripts/sync_core.ps1` (maintainer helper; optional for consumers)

## Consumer CI

Copy the workflow under `examples/github-actions/complexity-check.yml` into your project. Exit codes from `cli/analyze_project.gd`:

| Code | Meaning |
|------|---------|
| 0 | Analysis ok, no `threshold_fail` breaches |
| 1 | One or more functions exceeded `threshold_fail`, zero successful files, or `--fail-on-diff-regression` when `avg_cog` / `fail_count` increased vs baseline/previous |
| 2 | Tool / path / write error |

History: each successful CLI (and editor) analysis appends one JSON line to `complexity_history.jsonl` (override with `report.history_path` or `--history-path`). Use `--diff` for an informational delta; add `--baseline PATH` to compare against a JSON/JSONL snapshot.
