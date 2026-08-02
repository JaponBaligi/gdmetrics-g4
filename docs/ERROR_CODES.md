# Parse Error Code Map

Standardized error codes used by the analyzer. Errors are stored as strings in the
form `[CODE] message` for backwards compatibility.

## Severity Levels

- `error`: analysis failed or output is unreliable
- `warning`: analysis continued with degraded accuracy
- `info`: informational, no impact on results

## Code Table

| Code | Severity | Meaning |
| --- | --- | --- |
| `FILE_NOT_FOUND` | error | Input file does not exist |
| `FILE_OPEN_FAILED` | error | Input file could not be opened |
| `CONFIG_HELPER_MISSING` | warning | File helper could not be loaded |
| `CONFIG_FILE_NOT_FOUND` | warning | Config file not found |
| `CONFIG_OPEN_FAILED` | warning | Config file could not be opened |
| `CONFIG_INVALID_JSON` | warning | Config JSON is invalid |
| `CONFIG_INVALID_ROOT` | warning | Config root is not an object |
| `CONFIG_INVALID_TYPE` | warning | Config value has invalid type |
| `CONFIG_INVALID_VALUE` | warning | Config value has invalid value |
| `TOKEN_UNTERMINATED_COMMENT` | error | Reserved; GDScript has no `"""` comments (unused) |
| `TOKEN_UNTERMINATED_STRING` | error | Unterminated string literal |
| `TOKEN_UNBALANCED_PAREN` | error | Unbalanced parentheses |
| `TOKEN_UNBALANCED_BRACKET` | error | Unbalanced brackets |
| `TOKEN_UNBALANCED_BRACE` | error | Unbalanced braces |
| `TOKEN_UNKNOWN_CHAR` | warning | Unknown character in source |
| `TOKEN_PARSE_ERROR` | error | Tokenization parse error |
| `NO_TOKENS_FOUND` | error | No tokens were produced |
| `NO_FILES_FOUND` | error | No files matched include patterns |
| `FILE_DISCOVERY_FAILED` | error | Discovery root could not be opened |
| `CLASS_DECLARATION_MISSING` | warning | `class_name` without `class` |
| `EXTENDS_WITHOUT_CLASS` | warning | `extends` without `class` |
| `OUTPUT_PATH_FORBIDDEN` | error | Output path is protected |
| `ANALYSIS_FAILED` | error | Analysis failed unexpectedly |
| `UNKNOWN` | error | Error without code prefix |
