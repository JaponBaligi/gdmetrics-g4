extends Object

# Report generator for Godot 4.x (JSON.stringify, FileAccess)

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"

var FORBIDDEN_OUTPUT_PATHS = [
	"project.godot",
	".git",
	"src/",
	"cli/",
	"docs/",
	".github/"
]

var _error_codes = null

func generate_report(project_result, config) -> Dictionary:
	var report = {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"project": {
			"total_files": project_result.total_files,
			"successful_files": project_result.successful_files,
			"failed_files": project_result.failed_files,
			"totals": {
				"cc": project_result.total_cc,
				"cog": project_result.total_cog
			},
			"averages": {
				"cc": project_result.average_cc,
				"cog": project_result.average_cog,
				"confidence": project_result.average_confidence
			},
			"error_summary": project_result.error_summary,
			"error_severity_summary": project_result.error_severity_summary,
			"total_errors": project_result.total_errors,
			"performance": project_result.performance
		},
		"worst_offenders": {
			"cc": _format_worst_offenders(project_result.worst_cc_files, "cc"),
			"cog": _format_worst_offenders(project_result.worst_cog_files, "cog")
		},
		"files": _format_file_results(project_result.file_results),
		"errors": project_result.errors
	}
	if config.telemetry_config.get("enable_anonymous_reporting", false):
		report["telemetry"] = {
			"error_summary": project_result.error_summary,
			"error_severity_summary": project_result.error_severity_summary,
			"total_errors": project_result.total_errors
		}
	return report

func generate_csv(project_result, config) -> String:
	var rows = []
	rows.append(["file_path", "function_name", "CC", "C-COG", "confidence", "line_start", "line_end"])
	
	for result in project_result.file_results:
		if not result.success:
			continue
		for func_info in result.functions:
			var func_name = func_info.name
			var cc_value = 0
			var cog_value = 0
			if result.per_function_cc.has(func_name):
				cc_value = result.per_function_cc[func_name]
			if result.per_function_cog.has(func_name):
				cog_value = result.per_function_cog[func_name]
			
			rows.append([
				result.file_path,
				func_name,
				cc_value,
				cog_value,
				result.confidence,
				func_info.start_line,
				func_info.end_line
			])
	
	return _build_csv(rows)

func _format_worst_offenders(file_results: Array, metric: String) -> Array:
	var offenders = []
	for result in file_results:
		if result.success:
			var value = result.cc if metric == "cc" else result.cog
			offenders.append({
				"file": result.file_path,
				metric: value,
				"confidence": result.confidence
			})
	return offenders

func _format_file_results(file_results: Array) -> Array:
	var files = []
	for result in file_results:
		var file_data = {
			"file": result.file_path,
			"success": result.success,
			"cc": result.cc,
			"cog": result.cog,
			"confidence": result.confidence,
			"cc_breakdown": result.cc_breakdown,
			"cog_breakdown": result.cog_breakdown,
			"errors": result.errors,
			"max_nesting_depth": result.max_nesting_depth,
			"match_arm_count": result.match_arm_count,
			"lambda_count": result.lambda_count,
			"loc_code": result.loc_code,
			"max_params": result.max_params
		}
		if result.success:
			file_data["functions"] = _format_functions(result.functions, result.per_function_cog)
			file_data["classes"] = _format_classes(result.classes)
		files.append(file_data)
	return files

func _format_functions(functions: Array, per_function_cog: Dictionary = {}) -> Array:
	var func_list = []
	for func_info in functions:
		var func_data = {
			"name": func_info.name,
			"type": func_info.type,
			"start_line": func_info.start_line,
			"end_line": func_info.end_line,
			"parameters": func_info.parameters.size(),
			"return_type": func_info.return_type if func_info.return_type != "" else "void"
		}
		if per_function_cog.has(func_info.name):
			func_data["cog"] = per_function_cog[func_info.name]
		func_list.append(func_data)
	return func_list

func _format_classes(classes: Array) -> Array:
	var class_list = []
	for class_info in classes:
		class_list.append({
			"name": class_info.name,
			"class_name": class_info.class_name_decl,
			"extends": class_info.extends_class,
			"start_line": class_info.start_line,
			"end_line": class_info.end_line
		})
	return class_list

func write_report(report: Dictionary, output_path: String) -> bool:
	output_path = _sanitize_path(output_path)
	if not _check_output_overwrite(output_path):
		return false
	var json_string = JSON.stringify(report, "  ")
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_string)
	file = null
	return true

func write_csv(csv_text: String, output_path: String) -> bool:
	output_path = _sanitize_path(output_path)
	if not _check_output_overwrite(output_path):
		return false
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(csv_text)
	file = null
	return true

func _sanitize_path(path: String) -> String:
	if path.length() == 0:
		return "complexity_report.json"
	var sanitized = path.replace("\\", "/")
	while sanitized.find("../") >= 0:
		sanitized = sanitized.replace("../", "")
	while sanitized.begins_with("/"):
		sanitized = sanitized.substr(1)
	if sanitized.begins_with("res://"):
		sanitized = sanitized.substr(6)
	return sanitized

func _check_output_overwrite(output_path: String) -> bool:
	var normalized = output_path.replace("\\", "/").to_lower()
	for forbidden in FORBIDDEN_OUTPUT_PATHS:
		if normalized.find(forbidden.to_lower()) >= 0:
			print(_format_error("OUTPUT_PATH_FORBIDDEN", "Output path '%s' would overwrite protected path '%s'" % [output_path, forbidden]))
			return false
	return true

func _format_error(code: String, detail: String) -> String:
	if _error_codes == null:
		_error_codes = load(SRC_ROOT + "/error_codes.gd").new()
	return _error_codes.format(code, detail)

func generate_and_write(project_result, config) -> bool:
	var report = generate_report(project_result, config)
	var output_path = config.report_config["output_path"]
	return write_report(report, output_path)

func generate_and_write_csv(project_result, config) -> bool:
	var csv_text = generate_csv(project_result, config)
	var output_path = config.report_config.get("csv_output_path", "res://complexity_report.csv")
	return write_csv(csv_text, output_path)

func _build_csv(rows: Array) -> String:
	var lines: Array = []
	for row in rows:
		var escaped: Array = []
		for value in row:
			escaped.append(_csv_escape(value))
		var line = ""
		for i in range(escaped.size()):
			if i > 0:
				line += ","
			line += escaped[i]
		lines.append(line)
	return "\n".join(lines)

func _csv_escape(value) -> String:
	var text = "" if value == null else str(value)
	var needs_quotes = text.find(",") >= 0 or text.find("\"") >= 0 or text.find("\n") >= 0 or text.find("\r") >= 0
	if needs_quotes:
		text = text.replace("\"", "\"\"")
		text = "\"" + text + "\""
	return text

