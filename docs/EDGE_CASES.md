# GDScript Edge Cases Catalog

Reference for tokenizer / control-flow fidelity. Sources: Godot `gdscript_tokenizer.cpp`, GDScript reference, style guide, corpus games under `D:\test-3`, engine PRs (`when` guards #80085).

| ID | Construct | Engine | Priority | Expected metric effect | Fixture |
|---|---|---|---|---|---|
| LC1 | Line continuation `\` at EOL | 3+4 | P0 | No `TOKEN_UNKNOWN_CHAR`; tokens join | `line_cont_simple.gd` |
| LC2 | `\` then blank/comment lines | 3+4 | P0 | Skip then continue | `line_cont_after_comment_skip.gd` |
| LC3 | Mid-line `\` outside string | 3+4 | P0 | `TOKEN_PARSE_ERROR` | `line_cont_invalid_midline.gd` |
| M1 | `match` + arms (no `case`) | 3+4 | P0 | +1 match, +1 CC per arm | `match_g3_basic.gd` |
| M2 | Multi-pattern `1, 2:` | 3+4 | P0 | pattern_count for C-COG | `match_multi_pattern.gd` |
| M3 | Array/dict patterns | 3+4 | P1 | Arms counted | `match_array_dict.gd` |
| M4 | Wildcard `_` arm | 3+4 | P1 | +1 arm | `match_wildcard.gd` |
| M5 | `when` pattern guard | 4.2+ | P0 | guard +1 C-COG | `match_g4_when_guard.gd` |
| M6 | `&"StringName"` in match | 4 | P1 | Tokenized; arm counts | `match_stringname.gd` |
| T1 | Ternary `a if b else c` | 3+4 | P1 | +1 CC (not statement if) | `ternary_nested.gd` |
| L1 | `&&` / `\|\|` | 3+4 | P1 | Same as and/or when enabled | `logical_and_or_amp.gd` |
| F1 | `static func` + `-> T` | 3+4 | P0 | Detected as static_func | `static_func_return.gd` |
| C1 | `extends "res://…"` | 3+4 | P1 | File class extends set | `extends_string_path.gd` |
| N1 | `0x` / `0b` numbers | 3+4 | P1 | NUMBER tokens | (tokenizer unit) |
| S1 | Raw `r"…"` | 4 | P1 | STRING, escapes raw | `raw_string.gd` |
| S2 | `\u` / `\U` escapes | 4 | P2 | Inside STRING | `string_escape_unicode.gd` |
| P1 | `$Node` / `$"…"` | 3+4 | P1 | No unknown char | `dollar_path.gd` |
| P2 | `%Unique` / `$%Unique` | 4 | P1 | No unknown char | `percent_unique.gd` |
| P3 | `@"…"` NodePath-style literal | 4 (mixed) | P1 | No unknown `@` | `at_nodepath.gd` |
| S3 | Triple string + trail (`.dedent()…("\n")`) | 3+4 | P0 | No false `\` / balance errs | `triple_string_trail.gd` |
| S4 | Triple closer then `\` line cont | 3+4 | P0 | Continuation joins next line | `triple_string_cont_after.gd` |
| S5 | Regular `"…"` / `'…'` spanning lines | 4 | P0 | No unterminated-string errs | `multiline_regular_string.gd` |
| λ1 | Nested lambda | 4 | P1 | Lambda + body scoring | `lambda_nested.gd` |
| E1 | Empty file | 3+4 | P0 | success, CC=0 | `empty.gd` |
| E2 | BOM / CRLF | 3+4 | P2 | No crash | `bom_crlf.gd` |
| E3 | Unicode identifier | 3+4 | P2 | IDENTIFIER or soft warn | `unicode_ident.gd` |
| A1 | `yield` / `await` | 3 / 4 | P2 | Not CC decisions | `yield_await.gd` |
| D1 | `# gdmetrics:ignore` / `:pin` | 3+4 | P0 | Gate/Top-fixes skip or pin | `directive_ignore_pin.gd` |

## Scoring notes

- **CC**: base 1 + each `if`/`elif`/`for`/`while`/`match` + each **match arm** + `and`/`or`/`not` (+ `&&`/`||` when `count_logical_operators`) + ternary `if`. Lambda *bodies* still contribute decisions to file CC.
- **C-COG**: Sonar-style nesting; match arms use flat pattern contribution (`1 + (patterns-1) + guard`); statement `if` ≠ ternary `if`. Each lambda is +1; lambda body control-flow does **not** leak into the enclosing scope (nested lambdas still each +1).
- **`case` keyword**: does not exist in GDScript; arms are indented lines ending with `:` under `match`. Nested `match` tracks arm indent per match block.
