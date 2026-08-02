extends Object

# Evaluate per-function CC / C-COG and file-level structural metrics against config thresholds.
# Used by cli/analyze_project.gd and tests.

func evaluate(project_result, config) -> Dictionary:
	var cc_warn = int(config.cc_config.get("threshold_warn", 10))
	var cc_fail = int(config.cc_config.get("threshold_fail", 20))
	var cog_warn = int(config.cog_config.get("threshold_warn", 15))
	var cog_fail = int(config.cog_config.get("threshold_fail", 30))

	var structural = config.structural_config
	var nest_warn = int(structural.get("nesting_warn", 3))
	var nest_fail = int(structural.get("nesting_fail", 5))
	var params_warn = int(structural.get("params_warn", 4))
	var params_fail = int(structural.get("params_fail", 8))
	var loc_warn = int(structural.get("loc_warn", 300))
	var loc_fail = int(structural.get("loc_fail", 500))

	var warnings = []
	var failures = []
	var scanner = load("res://addons/gdscript_complexity/src/core/directive_scanner.gd").new()

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

			var line = func_info.start_line
			if cc_value >= cc_fail:
				failures.append(_row(result.file_path, func_name, line, "CC", cc_value, cc_fail))
			elif cc_value >= cc_warn:
				warnings.append(_row(result.file_path, func_name, line, "CC", cc_value, cc_warn))

			if cog_value >= cog_fail:
				failures.append(_row(result.file_path, func_name, line, "C-COG", cog_value, cog_fail))
			elif cog_value >= cog_warn:
				warnings.append(_row(result.file_path, func_name, line, "C-COG", cog_value, cog_warn))

		_check_structural(
			result, warnings, failures,
			nest_warn, nest_fail, params_warn, params_fail, loc_warn, loc_fail
		)

	scanner = null
	var fail_keys = []
	for row in failures:
		fail_keys.append("%s|%s|%s" % [row["file"], row["function"], row["metric"]])
	return {
		"warnings": warnings,
		"failures": failures,
		"fail_keys": fail_keys,
		"warn_count": warnings.size(),
		"fail_count": failures.size(),
		"cc_warn": cc_warn,
		"cc_fail": cc_fail,
		"cog_warn": cog_warn,
		"cog_fail": cog_fail,
		"nest_warn": nest_warn,
		"nest_fail": nest_fail,
		"params_warn": params_warn,
		"params_fail": params_fail,
		"loc_warn": loc_warn,
		"loc_fail": loc_fail
	}

func print_summary(gate: Dictionary) -> void:
	print("Thresholds: CC warn=%d fail=%d | C-COG warn=%d fail=%d | NEST warn=%d fail=%d | PARAMS warn=%d fail=%d | LOC warn=%d fail=%d" % [
		gate["cc_warn"], gate["cc_fail"], gate["cog_warn"], gate["cog_fail"],
		gate["nest_warn"], gate["nest_fail"], gate["params_warn"], gate["params_fail"],
		gate["loc_warn"], gate["loc_fail"]
	])
	if gate["warn_count"] > 0:
		print("WARN breaches (%d):" % gate["warn_count"])
		for row in gate["warnings"]:
			print("  WARN %s %s:%d %s=%d (limit %d)" % [
				row["file"], row["function"], row["line"], row["metric"], row["value"], row["limit"]
			])
	if gate["fail_count"] > 0:
		print("FAIL breaches (%d):" % gate["fail_count"])
		for row in gate["failures"]:
			print("  FAIL %s %s:%d %s=%d (limit %d)" % [
				row["file"], row["function"], row["line"], row["metric"], row["value"], row["limit"]
			])
	if gate["warn_count"] == 0 and gate["fail_count"] == 0:
		print("No threshold breaches.")

func _check_structural(
	result,
	warnings: Array,
	failures: Array,
	nest_warn: int,
	nest_fail: int,
	params_warn: int,
	params_fail: int,
	loc_warn: int,
	loc_fail: int
) -> void:
	var file_path = result.file_path
	var nest = int(result.max_nesting_depth)
	var params = int(result.max_params)
	var loc = int(result.loc_code)

	if nest >= nest_fail:
		failures.append(_row(file_path, "(file)", 1, "NEST", nest, nest_fail))
	elif nest >= nest_warn:
		warnings.append(_row(file_path, "(file)", 1, "NEST", nest, nest_warn))

	if params >= params_fail:
		failures.append(_row(file_path, "(file)", 1, "PARAMS", params, params_fail))
	elif params >= params_warn:
		warnings.append(_row(file_path, "(file)", 1, "PARAMS", params, params_warn))

	if loc >= loc_fail:
		failures.append(_row(file_path, "(file)", 1, "LOC", loc, loc_fail))
	elif loc >= loc_warn:
		warnings.append(_row(file_path, "(file)", 1, "LOC", loc, loc_warn))

func _row(file_path: String, func_name: String, line: int, metric: String, value: int, limit: int) -> Dictionary:
	return {
		"file": file_path,
		"function": func_name,
		"line": line,
		"metric": metric,
		"value": value,
		"limit": limit
	}
