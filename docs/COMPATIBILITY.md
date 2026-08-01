# Compatibility Matrix and Version-Specific Limitations

This repository supports **Godot 4.x** only. For Godot 3.x, see [gdmetrics-g3](https://github.com/JaponBaligi/gdmetrics-g3).

## Supported Versions

| Godot Version | Support Level | CLI Mode | Editor Plugin | Annotations | Confidence Cap |
|--------------|---------------|----------|---------------|-------------|---------------|
| 4.0 - 4.2    | Full          | +       | +            | +          | 1.0           |
| 4.3+         | Full          | +       | +            | +          | 1.0           |

**Legend:**
- Fully supported
- Limited support (best-effort, may have issues)
- Not supported

## Godot 4.x Features

**Supported:**
- Cyclomatic Complexity (CC) calculation
- Cognitive Complexity (C-COG) calculation
- CLI mode analysis
- JSON and CSV report generation
- Editor plugin UI
- `match` arm analysis (no `case` keyword; supports `when` guards)
- `await` keyword recognition
- Editor annotations via `add_error_annotation()` API
- Maximum confidence score: 1.0 (no cap)
- Parser accuracy: 90-93% typical, 95% in best cases

**Limitations:**
- Parser accuracy: 90-93% typical (best-effort)
- Complex string interpolation may reduce parse accuracy
- Nested lambdas may not be fully analyzed

**Note:** `yield` keyword is recognized but deprecated in favor of `await` in 4.x.

## Parser Architecture Limitations

### Block-Oriented Parsing

The parser is **block-oriented and control-flow focused**, not a full AST:

- **Parsed**: Function boundaries, class definitions, control structures (`if`, `for`, `while`, `match`)
- **Limited**: Expression parsing (sufficient for complexity calculation only)
- **Not Parsed**: Full expression trees, type information, semantic analysis

### Rationale

Complexity metrics require control flow structure, not complete semantic understanding. The parser focuses on:
1. Identifying decision points (if, elif, for, while, match, match arms, ternary, logical operators)
2. Tracking nesting depth for C-COG calculation
3. Determining function and class boundaries

## Confidence Scoring

### Godot 4.x
- **Maximum**: 1.0 (no cap)
- **Typical Range**: 0.85 - 0.95
- **Reason**: Better parser support, more accurate detection

### Confidence Components

Confidence score is calculated from:
- Token coverage (40% weight)
- Indentation consistency (20% weight)
- Block balance (20% weight)
- Parse errors (20% weight)

## Editor Integration

- Uses `ScriptEditor.add_error_annotation(script_path, line, severity, message)` API
- Supports severity levels (error, warning, info)
- Dock panel uses `Label.AUTOWRAP_WORD_SMART` enum
- Plugin lifecycle: `_enter_tree()`, `_exit_tree()`

## Testing Checklist

### Godot 4.0-4.2 - Full Functionality
- [ ] Plugin loads without errors
- [ ] Dock panel displays correctly
- [ ] Analysis runs successfully
- [ ] Editor annotations appear in script editor
- [ ] Configuration dialog works
- [ ] Export functionality works
- [ ] CLI mode works
- [ ] `match` arms (and `when` guards) are detected
- [ ] `await` keyword is recognized

## Known Limitations Summary

1. **Parser Accuracy**: Best-effort, not guaranteed. Typical accuracy: 90-93%
2. **Complex Syntax**: String interpolation, nested lambdas may reduce accuracy
3. **Edge Cases**: Some unusual code patterns may not be parsed correctly
4. **No Full AST**: Parser is block-oriented, not a complete semantic analyzer

## Reporting Issues

When reporting compatibility issues, please include:
- Godot version (full version string from `Engine.get_version_info()`)
- Plugin version
- Error messages or unexpected behavior
- Sample code that triggers the issue (if applicable)
- Whether CLI mode or editor plugin is affected
