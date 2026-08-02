@tool
extends AcceptDialog
class_name ComplexityHelpDialog

# Plain-language help for dock metrics and status labels.

const HELP_TEXT := """Know what to fix before you hate the project.

WHAT TO DO
• Click Find what to fix.
• Start with Top fixes (red / yellow).
• Select a row and click Open (or double-click) to jump there.
• Fix the hard-to-read code, then run again.

STATUS LABELS
• OK — fine for now; no rush.
• Hard to read — getting messy; plan a cleanup.
• Fix soon — high complexity; this is where bugs and confusion grow.

CC (Cyclomatic Complexity)
Counts decision paths: if, elif, for, while, match, and similar branches.
Higher CC ⇒ more paths to test and more ways the code can behave.
Useful for: “How many routes does this function have?”

C-COG (Cognitive Complexity)
Estimates how hard the code is for a human to read and hold in their head.
Nesting (ifs inside loops inside matches) raises the score a lot.
Useful for: “Will future-me (or a teammate) hate opening this file?”
Usually more important than CC for day-to-day maintainability.

WHY BOTH?
CC is about paths / testing. C-COG is about readability.
A function can have medium CC but high C-COG if it is deeply nested.
Top fixes prefer high C-COG so you open the scary code first.

CONFIDENCE (“Pretty sure”, etc.)
How sure the analyzer is that it understood the file.
Not a grade for your code quality.
Low confidence ⇒ weird syntax, parse trouble, or edge cases — treat scores carefully.
High confidence ⇒ safer to trust the numbers.

OTHER COLUMNS
• Nest — deepest indentation / nesting in the file.
• Params — most parameters on a function in that file.
• LOC — lines of code (rough size).

TREND
Compares this run to the previous saved run.
“Getting harder” means average C-COG or fail counts went up — debt is growing.

WHY THIS SCORE
Select a function (Top fixes or Project Results). The dock shows plain-language
reasons: which ifs, loops, nesting, and branches drove CC and C-COG.

IGNORE / PIN (in your .gd files)
Put a comment on the line above a function, or at the end of the func line:
• # gdmetrics:ignore — skip this function in Top fixes and fail counts
• # gdmetrics:pin — always keep it in Top fixes (your watch list)
Scores are still calculated; ignore only stops the nagging.

BIG SCARY FILES
Whole scripts that are Fix soon at file totals, or large + many hard functions.
Status Hot means that file is also recently changed in git (optional; skipped if no git).

TREND / REGRESSION
If avg C-COG rises or new Fix soon items appear vs the last run, the dock says
“Regression — project got harder.”

CONFIG
Change warn/fail thresholds and which folders to scan.
Defaults are fine for most projects.
Optional: report.churn_hotspots = auto|on|off; report.churn_since (git --since).

This tool measures complexity. It does not auto-fix or lint style.
"""

func _ready() -> void:
	title = "Help — what these numbers mean"
	ok_button_text = "Got it"
	dialog_hide_on_ok = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var label := Label.new()
	label.text = HELP_TEXT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)

func popup_help() -> void:
	popup_centered(Vector2i(520, 500))
