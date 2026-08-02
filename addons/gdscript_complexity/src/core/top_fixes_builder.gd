extends Object

# Shared Top-fixes ranking for dock + HTML. Dual Godot 3/4 compatible.

const SRC_ROOT := "res://addons/gdscript_complexity/src"

func build(project_result, config, limit: int = 10) -> Array:
	var entries = []
	if project_result == null or config == null:
		return entries

	var cc_warn = int(config.cc_config.get("threshold_warn", 10))
	var cc_fail = int(config.cc_config.get("threshold_fail", 20))
	var cog_warn = int(config.cog_config.get("threshold_warn", 15))
	var cog_fail = int(config.cog_config.get("threshold_fail", 30))
	var explainer = load(SRC_ROOT + "/core/score_explainer.gd").new()
	var scanner = load(SRC_ROOT + "/core/directive_scanner.gd").new()

	for result in project_result.file_results:
		if not result.success:
			continue
		var directives = result.per_function_directives
		if typeof(directives) != TYPE_DICTIONARY:
			directives = {}
		for func_info in result.functions:
			if scanner.is_ignored(func_info, directives):
				continue
			var func_name = func_info.name
			var cc_value = 0
			var cog_value = 0
			if result.per_function_cc.has(func_name):
				cc_value = int(result.per_function_cc[func_name])
			if result.per_function_cog.has(func_name):
				cog_value = int(result.per_function_cog[func_name])
			var pinned = scanner.is_pinned(func_info, directives)
			var label_text = _label(cc_value, cog_value, cc_warn, cc_fail, cog_warn, cog_fail)
			if label_text == "OK" and not pinned:
				continue
			if label_text == "OK" and pinned:
				label_text = "Pinned"
			var cc_bd = {}
			var cog_bd = {}
			if result.per_function_cc_breakdown.has(func_name):
				cc_bd = result.per_function_cc_breakdown[func_name]
			if result.per_function_cog_breakdown.has(func_name):
				cog_bd = result.per_function_cog_breakdown[func_name]
			var why = ""
			if explainer != null:
				why = explainer.explain_function(cc_value, cog_value, cc_bd, cog_bd)
			entries.append({
				"script_path": result.file_path,
				"function": func_name,
				"line": int(func_info.start_line),
				"cc": cc_value,
				"cog": cog_value,
				"label": label_text,
				"cc_breakdown": cc_bd,
				"cog_breakdown": cog_bd,
				"why": why,
				"pinned": pinned
			})

	_sort_entries(entries)
	if entries.size() > limit:
		var trimmed = []
		for i in range(limit):
			trimmed.append(entries[i])
		return trimmed
	return entries

func _label(cc: int, cog: int, cc_warn: int, cc_fail: int, cog_warn: int, cog_fail: int) -> String:
	if cog >= cog_fail or cc >= cc_fail:
		return "Fix soon"
	if cog >= cog_warn or cc >= cc_warn:
		return "Hard to read"
	return "OK"

func _sort_entries(entries: Array) -> void:
	# Insertion sort: Fix soon > Hard to read > Pinned; then C-COG; then CC.
	for i in range(1, entries.size()):
		var key_item = entries[i]
		var j = i - 1
		while j >= 0 and _worse(key_item, entries[j]):
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = key_item

func _worse(a, b) -> bool:
	var ar = _rank(str(a.get("label", "")))
	var br = _rank(str(b.get("label", "")))
	if ar != br:
		return ar > br
	var a_cog = int(a.get("cog", 0))
	var b_cog = int(b.get("cog", 0))
	if a_cog != b_cog:
		return a_cog > b_cog
	return int(a.get("cc", 0)) > int(b.get("cc", 0))

func _rank(label: String) -> int:
	if label == "Fix soon":
		return 3
	if label == "Hard to read":
		return 2
	if label == "Pinned":
		return 1
	return 0
