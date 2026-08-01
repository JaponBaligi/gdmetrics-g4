Release Package Structure

This folder documents the intended release package layout. CI creates a zip
from these paths on version tags (see `.github/workflows/ci.yml`).

Package contents:
- `addons/gdscript_complexity/`
- `docs/USER_GUIDE.md`
- `docs/TECHNICAL.md`
- `docs/COMPATIBILITY.md`
- `docs/BREAKING_CHANGES.md`
- `docs/ERROR_CODES.md`
- `docs/DISTRIBUTION.md`
- `docs/CHANGELOG_TEMPLATE.md`
- `README.md`
- `LICENSE`
- `complexity_config.example.json`

Version tagging:
- Use `vMAJOR.MINOR.PATCH` (example: `v0.1.3`).
- Keep `addons/gdscript_complexity/plugin.cfg` `version=` in sync (without the `v` prefix).

Release notes:
- Update `release/NOTES.md` before tagging.
