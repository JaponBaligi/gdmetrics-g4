extends Object

# Rank "big scary files" (god-scripts) for dock + HTML.
# Dual Godot 3/4 compatible (synced via sync_core.ps1).

func build(project_result, config, limit: int = 5) -> Array:
	var entries = []
	if project_result == null or config == null:
		return entries

	var cc_warn = int(config.cc_config.get("threshold_warn", 10))
	var cc_fail = int(config.cc_config.get("threshold_fail", 20))
	var cog_warn = int(config.cog_config.get("threshold_warn", 15))
	var cog_fail = int(config.cog_config.get("threshold_fail", 30))
	var loc_warn = int(config.structural_config.get("loc_warn", 300))
	var complex_min = int(config.report_config.get("god_complex_func_min", 3))

	for result in project_result.file_results:
		if not result.success:
			continue
		var func_count = result.functions.size()
		var complex_count = _complex_function_count(result, cc_warn, cog_warn)
		var loc = int(result.loc_code)
		var file_label = _label(int(result.cc), int(result.cog), cc_warn, cc_fail, cog_warn, cog_fail)
		var reason = ""
		if file_label == "Fix soon":
			reason = "file_totals_fail"
		elif loc >= loc_warn and int(result.cog) >= cog_warn and complex_count >= complex_min:
			reason = "large_and_complex"
		else:
			continue
		var reason_text = "File totals are Fix soon"
		if reason == "large_and_complex":
			reason_text = "Large file with many hard functions"
		entries.append({
			"script_path": result.file_path,
			"cc": int(result.cc),
			"cog": int(result.cog),
			"loc_code": loc,
			"function_count": func_count,
			"complex_function_count": complex_count,
			"label": file_label if file_label != "OK" else "Hard to read",
			"reason": reason,
			"reason_text": reason_text,
			"line": 1
		})

	_sort_entries(entries)
	if entries.size() > limit:
		var trimmed = []
		for i in range(limit):
			trimmed.append(entries[i])
		return trimmed
	return entries

func _complex_function_count(result, cc_warn: int, cog_warn: int) -> int:
	var n = 0
	var scanner = load("res://addons/gdscript_complexity/src/core/directive_scanner.gd").new()
	var directives = result.per_function_directives
	if typeof(directives) != TYPE_DICTIONARY:
		directives = {}
	for func_info in result.functions:
		if scanner.is_ignored(func_info, directives):
			continue
		var name = func_info.name
		var cc = 0
		var cog = 0
		if result.per_function_cc.has(name):
			cc = int(result.per_function_cc[name])
		if result.per_function_cog.has(name):
			cog = int(result.per_function_cog[name])
		if cc >= cc_warn or cog >= cog_warn:
			n += 1
	scanner = null
	return n

func _label(cc: int, cog: int, cc_warn: int, cc_fail: int, cog_warn: int, cog_fail: int) -> String:
	if cog >= cog_fail or cc >= cc_fail:
		return "Fix soon"
	if cog >= cog_warn or cc >= cc_warn:
		return "Hard to read"
	return "OK"

func _sort_entries(entries: Array) -> void:
	for i in range(1, entries.size()):
		var key_item = entries[i]
		var j = i - 1
		while j >= 0 and _worse(key_item, entries[j]):
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = key_item

func _worse(a, b) -> bool:
	var ar = 1 if str(a.get("reason", "")) == "file_totals_fail" else 0
	var br = 1 if str(b.get("reason", "")) == "file_totals_fail" else 0
	if ar != br:
		return ar > br
	var a_cog = int(a.get("cog", 0))
	var b_cog = int(b.get("cog", 0))
	if a_cog != b_cog:
		return a_cog > b_cog
	return int(a.get("loc_code", 0)) > int(b.get("loc_code", 0))
