extends Object

# Evaluate per-function CC / C-COG against config thresholds.
# Used by cli/analyze_project.gd and tests.

func evaluate(project_result, config) -> Dictionary:
	var cc_warn = int(config.cc_config.get("threshold_warn", 10))
	var cc_fail = int(config.cc_config.get("threshold_fail", 20))
	var cog_warn = int(config.cog_config.get("threshold_warn", 15))
	var cog_fail = int(config.cog_config.get("threshold_fail", 30))

	var warnings = []
	var failures = []

	for result in project_result.file_results:
		if not result.success:
			continue
		for func_info in result.functions:
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

	return {
		"warnings": warnings,
		"failures": failures,
		"warn_count": warnings.size(),
		"fail_count": failures.size(),
		"cc_warn": cc_warn,
		"cc_fail": cc_fail,
		"cog_warn": cog_warn,
		"cog_fail": cog_fail
	}

func print_summary(gate: Dictionary) -> void:
	print("Thresholds: CC warn=%d fail=%d | C-COG warn=%d fail=%d" % [
		gate["cc_warn"], gate["cc_fail"], gate["cog_warn"], gate["cog_fail"]
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

func _row(file_path: String, func_name: String, line: int, metric: String, value: int, limit: int) -> Dictionary:
	return {
		"file": file_path,
		"function": func_name,
		"line": line,
		"metric": metric,
		"value": value,
		"limit": limit
	}
