# GDScript Complexity Analyzer

**gdmetrics is a static analyzer that measures code complexity and maintainability metrics for Godot (GDScript) projects.**

> ***bad code, target PCs / optimized code, target electricity.***

A Godot EditorPlugin that analyzes GDScript code complexity using Cyclomatic Complexity (CC) and Cognitive Complexity (C-COG) metrics.

## Who Is This For?

- **Godot developers** working on medium to large projects
- **Developers preparing for refactoring** who need metrics to guide prioritization
- **Anyone tracking CC / CCOG-style complexity metrics** as part of code quality standards
- **CI/CD pipelines** that want to enforce complexity thresholds

## Why Use This?

- **Identify risky scripts** before refactoring (find high-complexity code early)
- **Measure technical debt growth** over time with automated reports
- **Use metrics as part of code review** to guide refactoring efforts
- **Set complexity thresholds** to prevent complexity regression in your codebase

## Features

- **Cyclomatic Complexity (CC)**: Measures the number of linearly independent paths through code
- **Cognitive Complexity (C-COG)**: Measures code readability and maintainability
- **Godot 4.x**: Built for Godot 4.2+ (see [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3) for Godot 3.x)
- **CLI Mode**: Run analysis from command line for CI/CD integration
- **Editor Integration**: Visual complexity warnings in the script editor
- **JSON Reports**: Export detailed analysis reports
- **CSV Reports**: Export per-function metrics
- **Configurable Thresholds**: Set custom complexity limits

## Installation

```bash
git clone https://github.com/JaponBaligi/gdmetrics-g4
cd gdmetrics-g4
```

For Godot 3.x, use [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3) instead.

Then:
1. Copy the `addons/gdscript_complexity` folder to your Godot project's `addons/` directory
2. Open your project in Godot
3. Go to **Project > Project Settings > Plugins**
4. Enable "GDScript Complexity Analyzer"

## Supported Versions

**This plugin is a source-based addon with no prebuilt binaries.** Version numbers indicate code maturity, not binary stability.

This repository supports **Godot 4.x** only. Godot 3.x lives in [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3).

| Godot Version | Support Level | CI Testing | Notes |
|---------------|---------------|------------|-------|
| 4.x (tested on 4.2) | ✅ **Actively supported** | ✅ Yes | Full CC and C-COG metrics; `match`/`case` support; highest accuracy (90-93%) |
| 4.0-4.1 | ✅ **Supported** | ❌ No* | Should work identically to 4.2; contact maintainer for specific version testing |
| 4.3+ | ⚠️ **Forward compatible** | ❌ No* | Untested; likely works but not officially verified |

For detailed compatibility information, see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Usage

### Editor Plugin

1. Open the dock panel (should appear automatically when plugin is enabled)
2. Click "Analyze Project" to analyze all GDScript files
3. View results in the dock panel
4. Click on files/functions to see detailed metrics
5. Use "Configure" button to adjust thresholds and settings

### CLI Mode

```bash
godot --headless --script cli/analyze_project.gd -- \
  --project-path . --output report.json --csv-output report.csv
```

Exit codes: `0` ok, `1` `threshold_fail` breach (or no successful files), `2` tool/path error.  
Use `--no-fail-on-threshold` to always exit 0/2 (report only).  
`tests/ci_test.gd` remains a thin wrapper around this script.

Copy-paste GitHub Actions: [`examples/github-actions/complexity-check.yml`](examples/github-actions/complexity-check.yml).

The report will be written to `report.json`.

## Example Output

### Console Output

When analysis completes, you'll see output like:

```
[GDScript Complexity Analyzer] Analysis completed
Files analyzed: 42
Total CC: 342 (avg: 8.14)
Total C-COG: 725 (avg: 17.26)
High complexity files: 3
```

### JSON Report Format

Actual generator shape (see `report_generator.gd`):

```json
{
  "version": "1.0",
  "timestamp": "2026-01-26T10:30:00",
  "project": {
    "total_files": 42,
    "successful_files": 42,
    "failed_files": 0,
    "totals": { "cc": 342, "cog": 725 },
    "averages": { "cc": 8.14, "cog": 17.26, "confidence": 0.93 }
  },
  "worst_offenders": {
    "cc": [],
    "cog": []
  },
  "files": [],
  "errors": []
}
```

CSV rows include per-function `CC` and `C-COG`.

### Usage Examples

- Analyze a project and export JSON + CSV (fails CI when thresholds exceeded):
```bash
godot --headless --script cli/analyze_project.gd -- --project-path . --output report.json --csv-output report.csv
```
- Enable auto export in config:
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

## Configuration

Create a `complexity_config.json` file in your project root (or copy `complexity_config.example.json`):

```json
{
  "include": ["res://**/*.gd"],
  "exclude": ["res://addons/**", "res://tests/**"],
  "cc": {
    "count_logical_operators": true,
    "threshold_warn": 10,
    "threshold_fail": 20
  },
  "cog": {
    "nesting_penalty": 1,
    "threshold_warn": 15,
    "threshold_fail": 30
  },
  "parser": {
    "parser_mode": "balanced",
    "max_expected_errors_per_100_lines": 5
  },
  "report": {
    "formats": ["json", "csv"],
    "output_path": "res://complexity_report.json",
    "csv_output_path": "res://complexity_report.csv",
    "auto_export": false
  },
  "performance": {
    "enable_caching": true,
    "cache_path": ".gdcomplexity_cache",
    "incremental_analysis": true
  }
}
```

### Configuration Reference (Common Fields)

- `include`: file patterns to analyze (default: `["res://**/*.gd"]`)
- `exclude`: file patterns to skip
- `cc.threshold_warn` / `cc.threshold_fail`: CC warning/fail thresholds
- `cog.threshold_warn` / `cog.threshold_fail`: C-COG warning/fail thresholds
- `report.formats`: list of report outputs (`json`, `csv`)
- `report.output_path`: JSON output path
- `report.csv_output_path`: CSV output path
- `report.auto_export`: auto write after analysis
- `performance.enable_caching`: enable incremental caching
- `performance.cache_path`: cache directory

For full options, see `complexity_config.example.json`.

## Configuration & Defaults

**Default Behavior When No Config File is Present:**
- If no `complexity_config.json` is found, the analyzer uses built-in defaults
- Default patterns: `include: ["res://**/*.gd"]`, `exclude` includes `.git`, `.godot`, `addons/gdscript_complexity/**`, `tests/**`, and similar noise paths
- Default CC thresholds: warn at 10, fail at 20
- Default COG thresholds: warn at 15, fail at 30
- Caching is **enabled by default** for performance

**Missing Configuration Warnings in CI:**
- CI logs may report "Using default configuration" if no config file is present
- **These warnings are non-fatal** and do not cause test failures
- Analysis proceeds normally with sensible defaults
- To suppress warnings, create a `complexity_config.json` (or copy the `.example` file)

**Configuration Stabilization:**
- Current defaults are tuned for typical GDScript projects
- Configuration schema and defaults will be stabilized in a later release (v1.0)
- Breaking configuration changes may occur in releases before v1.0

## Known Issues

- **Editor shutdown leak warnings**: Godot may print `ObjectDB instances leaked at exit` with `GDScript` resources (e.g. `logger.gd`, `batch_analyzer.gd`). These are engine-level script cache artifacts seen in the editor after plugin use. They do not affect analysis output. If needed, run the editor with `--verbose` and capture the shutdown log for investigation.

### Caching System

The analyzer includes a content-based caching system to speed up subsequent analyses:

- **Content-based hashing**: Files are hashed by content (not modification time), so cache remains valid even if files are copied or moved
- **Config-aware**: Cache automatically invalidates when configuration changes
- **Incremental analysis**: Only changed files are re-analyzed, significantly reducing analysis time on large projects
- **Automatic cleanup**: Orphaned cache entries (for deleted files) are automatically removed
- **Disableable**: Set `"enable_caching": false` in the `performance` section to disable

Cache is stored in `.gdcomplexity_cache/` by default (configurable via `cache_path`).

### Auto Export

Set `"report.auto_export": true` to automatically write reports after analysis. Formats are controlled by `"report.formats"` (e.g., `["json", "csv"]`).

## Troubleshooting

- **No editor annotations**: If annotations are unavailable, the plugin logs warnings to the console.
- **CSV not generated**: Ensure `report.formats` includes `csv`, set `report.csv_output_path`, or pass `--csv-output` in CLI mode.
- **Files analyzed: 0**: Check `include`/`exclude` patterns and confirm the project contains `.gd` files under `res://`.
- **Stale results**: Disable caching (`performance.enable_caching = false`) or delete the cache directory.
- **Low confidence scores**: The parser is block-oriented and not a full AST; review `Known Limitations` and `Confidence Scores`.

## FAQ

- **Does it modify my scripts?** No. It only reads `.gd` files and generates reports.
- **Need Godot 3.x?** Use [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3).
- **Can I disable editor warnings?** Yes. Set `report.annotate_editor` to `false`.

## Godot 4.x Features

- All metrics available (CC, C-COG)
- `match`/`case` statements supported
- Annotation-based editor integration
- Typical accuracy 90-93%

## Complexity Metrics

### Cyclomatic Complexity (CC)

Formula: `CC = 1 (base) + number of decision points`

Decision points include:
- `if`, `elif`, `for`, `while` statements
- `match`/`case` statements (Godot 4.x only)
- Logical operators (`and`, `or`, `not`)

### Cognitive Complexity (C-COG)

Formula: `C-COG = sum of (1 + nesting_depth) for each control structure`

- Each control structure adds +1 base
- Each nesting level adds +1 to the contribution
- `case` statements add +1 regardless of nesting depth

## Testing

Run unit tests:

```bash
# Tokenizer tests
godot --headless --script tests/test_tokenizer_unit.gd

# CC calculator tests
godot --headless --script tests/test_cc_calculator.gd

# C-COG calculator tests
godot --headless --script tests/test_cog_calculator.gd

# Confidence calculator tests
godot --headless --script tests/test_confidence_calculator.gd

# Annotation manager tests
godot --headless --script tests/test_annotation_manager.gd

# Verify fixtures
godot --headless --script tests/verify_cc_cog.gd

# CSV export
godot --headless --script tests/test_csv_export.gd

# Advanced C-COG rules
godot --headless --script tests/test_cog_advanced.gd

# Confidence validation/tuning (optional)
godot --headless --script tests/validate_confidence.gd -- --step 0.1
godot --headless --script tests/validate_confidence.gd -- --step 0.1 --apply
```

## CI & Testing Transparency

### CI Infrastructure

**CI Environment:**
- **Godot Version**: 4.2.0 (headless mode only)
- **OS**: Ubuntu Linux (latest)
- **Frequency**: On every push to `main`, pull request, and tagged releases
- **Status**: See GitHub Actions workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

### Fixture Files & Tokenization Errors

**Malformed / Invalid Syntax Files:**
- The test suite includes GDScript files with **intentionally invalid or malformed syntax**
- These files are used to verify **error detection and graceful handling**
- Tokenization errors in these files are **expected by design**
- Such test files are **excluded from verification** and do **not fail CI**

**CI Log Interpretation:**
- CI logs may contain `[Tokenizer Error]`, `[Parse Error]`, or similar messages
- **These are expected and normal** — they demonstrate the analyzer catches syntax issues
- Log cleanliness does not determine CI success
- CI success is determined solely by **test pass/fail status** (`// PASS`, `// FAIL` markers)

### Known Godot Headless Mode Artifacts

**ObjectDB / Resource Cleanup Warnings:**
- Godot may print warnings like `ObjectDB instances leaked at exit` or `GDScript instances still referenced`
- These are **known Godot headless mode artifacts** (not plugin bugs)
- They typically reference cached scripts (e.g., `logger.gd`, `batch_analyzer.gd`)
- These warnings do **not affect analysis output** and do **not fail CI**

**Exit Code Handling:**
- CI checks exit codes, not stderr/stdout log content
- Exit code 0 = success, regardless of logged warnings
- For detailed investigation, check uploaded CI artifacts (reports, metrics)

### CI Success Criteria

✅ CI passes when:
- All fixture tests produce expected CC/COG values
- All confidence validation thresholds are met
- Tokenizer error handling is verified
- No **unhandled exceptions** or crashes occur
- Exit code is 0

❌ CI fails when:
- Fixture values mismatch expected results
- Confidence validation thresholds not met
- Unhandled exceptions occur
- Exit code is non-zero

**Log messages alone do not cause CI failure.**

## Known Limitations

### Scope Clarification

**What This Tool Is:**
- **Static analyzer**: Examines code structure without executing it
- **Metrics calculator**: Measures CC and C-COG based on control flow patterns
- **Code analyzer**: Reports complexity findings for review and refactoring

**What This Tool Is NOT:**
- ❌ **Not a linter**: Does not enforce code style or conventions
- ❌ **Not a compiler**: Does not perform semantic analysis or type checking
- ❌ **Not a runtime profiler**: Does not measure execution time or memory usage
- ❌ **Not a code fixer**: Does not modify or refactor code automatically

**Error Reporting:**
- Syntactically invalid files are **reported, not fixed**
- Error messages identify problematic files but do not attempt repairs
- Error reporting is part of **intended behavior**, not a limitation
- Files with syntax errors are skipped; analysis continues on valid files

This tool is a **static analyzer**, not a runtime profiler. Understand its limitations:

### Technical Limitations

- **Parser Accuracy**: Block-oriented parser, not full AST (typical 90-93% accuracy on Godot 4.x)
- **GDScript Only**: Does not analyze C#, C++, or other Godot languages
- **Metrics are Heuristic-Based**: CC and C-COG are approximations based on control flow patterns, not execution traces
- **Expression Parsing**: Shallow parsing (by design, sufficient for complexity metrics)
- **Metrics reflect code structure**: Numbers measure structural complexity, not algorithmic complexity

### Practical Limitations

- Large files (10k+ lines) may have slower analysis
- Cache requires disk space (.gdcomplexity_cache/)
- CLI mode requires running Godot in headless mode

## Confidence Scores

Confidence scores estimate parse reliability. Use `tests/validate_confidence.gd` to compute r² against fixtures and optionally write tuned weights to `complexity_config.json`. Default weights are tuned via this tool.

## Release & Distribution Policy

### Release Strategy

**Git Tags = Tested Releases:**
- Releases are tagged in git (e.g., `v0.1.0`, `v0.2.0`)
- Git tags correspond to releases tested and verified via CI
- Only versions with **passing CI tests** are tagged and released
- Untagged commits may contain experimental features

**Current Release Status:**
- **v0.3.0** is labeled as **early release / pre-stable**
- Versioning follows [Pride Versioning](https://pridever.org/) (`PROUD.DEFAULT.SHAME`); see [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)
- **Breaking changes may occur before PROUD 1.0.0** (see [docs/BREAKING_CHANGES.md](docs/BREAKING_CHANGES.md))
- Configuration, CLI arguments, and output formats may change
- Upgrades between 0.x DEFAULT releases may require manual adjustments

### Distribution Channels

**GitHub Releases:**
- Official release packages available at https://github.com/JaponBaligi/gdmetrics-g4/releases
- Each release includes the `gdscript_complexity` addon zipped with documentation

**itch.io:**
- Releases are mirrored to itch.io for convenient access
- itch.io releases **do not include separate binaries** — same source addon as GitHub
- itch.io is a distribution mirror, not a separate build

**Package Contents:**
- Source code of `addons/gdscript_complexity/`
- `cli/` (project analysis entrypoint)
- `examples/github-actions/` consumer workflow template
- Documentation files (README, USER_GUIDE, TECHNICAL, DISTRIBUTION, etc.)
- Example configuration files
- **No prebuilt binaries, DLLs, or OS-specific artifacts included**

### Version Stability Timeline

- **0.x (current)**: Pride DEFAULT/SHAME releases; breaking changes possible
- **1.0.0 (planned PROUD)**: Stable API, configuration, and output formats
- **2.0.0+ (future PROUD)**: Major feature additions after a proud blank slate

For detailed breaking changes, see the [BREAKING_CHANGES.md](docs/BREAKING_CHANGES.md) log.

## Roadmap

Versions use [Pride Versioning](https://pridever.org/) (`PROUD.DEFAULT.SHAME`). One tagged release at a time.

### Current Release (v0.3.0 — DEFAULT)
- ✅ CC and C-COG metrics
- ✅ JSON and CSV export
- ✅ HTML report (CLI `--html-output` + dock Export HTML)
- ✅ Dock Nest / Params / LOC columns
- ✅ Structural threshold gates (NEST / PARAMS / LOC)
- ✅ JSON per-function `"cc"` field
- ✅ Godot 4.x support
- ✅ Caching system
- ✅ CLI integration (`cli/analyze_project.gd`)
- ✅ Match/`when`, lambdas, multiline strings, edge-case corpus gates
- ✅ `threshold_fail` CI exit codes + breach summary
- ✅ Consumer GitHub Actions template (`examples/github-actions/`)

### Planned (later DEFAULT / PROUD — not started until prior tag ships)
- 🔲 0.4.0 — Complexity trend tracking
- 🔲 1.0.0 PROUD — schema freeze, shared-core, g4 annotations
- 🔲 Custom metric plugins (after 1.0)

### Under Consideration
- Halstead Metrics
- Maintainability Index calculation
- Godot 5.x when stable

## License

Licensed under the **MIT License**. See [LICENSE](LICENSE) file for full details.

Permission is granted to use, copy, modify, and distribute this software in accordance with the MIT License.

## Documentation

- [User Guide](docs/USER_GUIDE.md) - Installation, configuration, usage, troubleshooting
- [Technical Documentation](docs/TECHNICAL.md) - Architecture and parser details
- [Compatibility Matrix](docs/COMPATIBILITY.md) - Version support details
- [Breaking Changes Log](docs/BREAKING_CHANGES.md) - Release-impacting changes
- [Error Codes](docs/ERROR_CODES.md) - Standardized error codes and severities
- [Distribution Guide](docs/DISTRIBUTION.md) - Release packaging and tags
- [Changelog Template](docs/CHANGELOG_TEMPLATE.md) - Release notes format


## Special Thanks

***Special thanks to r2d2meuleu for starring my project — this is my first star***