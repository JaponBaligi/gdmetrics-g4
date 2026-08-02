extends Object

# Build plain-language "why this score" strings from CC / C-COG breakdowns.
# Additive helper — does not change metric formulas.
# Dual Godot 3/4 compatible (synced via sync_core.ps1).

const COG_LABELS := {
	"if": "if branches (nesting counted)",
	"elif": "else-if branches",
	"for": "for loops",
	"while": "while loops",
	"match": "match blocks",
	"case": "match arms",
	"ternary": "inline ? choices",
	"and": "and conditions",
	"or": "or conditions",
	"not": "not conditions",
	"return": "early returns",
	"break": "breaks",
	"continue": "continues",
	"lambda": "inline functions"
}

const CC_LABELS := {
	"if": "if",
	"elif": "elif",
	"for": "for",
	"while": "while",
	"match": "match",
	"case": "match arm",
	"ternary": "ternary",
	"and": "and",
	"or": "or",
	"not": "not"
}

func explain_function(cc: int, cog: int, cc_breakdown: Dictionary, cog_breakdown: Dictionary) -> String:
	var cog_parts = _top_parts(cog_breakdown, COG_LABELS, 4)
	var cc_parts = _top_parts(cc_breakdown, CC_LABELS, 4, ["base"])

	var out = "C-COG %d" % cog
	if cog_parts.size() > 0:
		out += " mainly from " + _join_parts(cog_parts)
	elif cog <= 1:
		out += " (simple — little nesting or branching)"
	else:
		out += " (mixed control flow)"

	out += ". CC %d" % cc
	if cc_parts.size() > 0:
		out += " = 1 base + " + _join_parts(cc_parts)
	else:
		out += " (base path only)"
	out += "."
	return out

func explain_file(cc: int, cog: int, cc_breakdown: Dictionary, cog_breakdown: Dictionary) -> String:
	return "File totals — " + explain_function(cc, cog, cc_breakdown, cog_breakdown)

func _top_parts(breakdown: Dictionary, labels: Dictionary, limit: int, skip_keys: Array = []) -> Array:
	var items = []
	for key in breakdown.keys():
		if skip_keys.has(key):
			continue
		var value = int(breakdown[key])
		if value <= 0:
			continue
		var label = str(labels[key]) if labels.has(key) else str(key)
		items.append({"key": key, "label": label, "value": value})
	_sort_by_value_desc(items)
	var parts = []
	var n = items.size()
	if n > limit:
		n = limit
	for i in range(n):
		var item = items[i]
		parts.append("%s (+%d)" % [item["label"], item["value"]])
	return parts

func _sort_by_value_desc(items: Array) -> void:
	# Insertion sort — avoids Callable / sort_custom API differences between Godot 3 and 4.
	for i in range(1, items.size()):
		var key_item = items[i]
		var j = i - 1
		while j >= 0 and int(items[j]["value"]) < int(key_item["value"]):
			items[j + 1] = items[j]
			j -= 1
		items[j + 1] = key_item

func _join_parts(parts: Array) -> String:
	if parts.size() == 0:
		return ""
	if parts.size() == 1:
		return str(parts[0])
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	var out = ""
	for i in range(parts.size()):
		if i > 0:
			if i == parts.size() - 1:
				out += ", and "
			else:
				out += ", "
		out += str(parts[i])
	return out
