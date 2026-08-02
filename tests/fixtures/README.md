# Test Fixtures Reference

This directory contains GDScript test files with known CC (Cyclomatic Complexity) and C-COG (Cognitive Complexity) values.

## Fixture Files

| File | CC | C-COG | Description |
|------|----|----|-------------|
| `simple_function.gd` | 1 | 0 | Base complexity only, no control flow |
| `if_statement.gd` | 2 | 3 | Single if statement (depth 1 + return penalty) |
| `if_elif_else.gd` | 3 | 6 | if/elif/else chain (returns inside control flow) |
| `for_loop.gd` | 2 | 2 | Single for loop (depth 1) |
| `while_loop.gd` | 2 | 2 | Single while loop (depth 1) |
| `nested_control_flow.gd` | 4 | 9 | Nested if/for structures (depth 1/2/3) |
| `match_statement.gd` | 2 | 5 | Match statement with returns |
| `logical_operators.gd` | 5 | 8 | Logical operators (and/or) across two ifs |
| `deep_nesting.gd` | 5 | 20+ | Deeply nested structures (10+ levels) |
| `class_with_inheritance.gd` | 2 | 2 | Class with extends |
| `empty_file.gd` | 1 | 0 | Empty file (base CC only) |
| `with_yield.gd` | 2 | 2 | yield syntax fixture (if at depth 1) |
| `no_match.gd` | 3 | 6 | File without match (returns inside control flow) |
| `annotations.gd` | 2 | 2 | File with @tool, @export annotations |
| `malformed_syntax.gd` | - | - | Malformed syntax (should handle gracefully) |
| `unterminated_string.gd` | - | - | Unterminated string (should handle gracefully) |
| `unbalanced_brackets.gd` | - | - | Unbalanced brackets (should handle gracefully) |
| `large_file.gd` | - | - | Large file placeholder (for performance testing) |

## CC / C-COG rules

Canonical scoring and edge constructs: [docs/EDGE_CASES.md](../../docs/EDGE_CASES.md).

GDScript has no `case` keyword — match arms are indented lines ending with `:` under `match`.

## Usage

These fixtures are used by:
- `tests/verify_cc_cog.gd` - Verification script that checks calculated values match expected
- Unit tests for CC and C-COG calculators
- Integration tests for full analysis pipeline
