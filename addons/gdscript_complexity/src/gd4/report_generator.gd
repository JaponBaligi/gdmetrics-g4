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
	var gods = _god_scripts_payload(project_result, config)
	if gods.size() > 0:
		report["god_scripts"] = gods
	var hot = _churn_payload(gods, config)
	if hot.size() > 0:
		report["churn_hotspots"] = hot
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
			file_data["functions"] = _format_functions(
				result.functions,
				result.per_function_cc,
				result.per_function_cog,
				result.per_function_cc_breakdown,
				result.per_function_cog_breakdown
			)
			file_data["classes"] = _format_classes(result.classes)
		files.append(file_data)
	return files

func _format_functions(
	functions: Array,
	per_function_cc: Dictionary = {},
	per_function_cog: Dictionary = {},
	per_function_cc_breakdown: Dictionary = {},
	per_function_cog_breakdown: Dictionary = {}
) -> Array:
	var explainer = load(SRC_ROOT + "/core/score_explainer.gd").new()
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
		var cc_value = 0
		var cog_value = 0
		if per_function_cc.has(func_info.name):
			cc_value = int(per_function_cc[func_info.name])
			func_data["cc"] = cc_value
		if per_function_cog.has(func_info.name):
			cog_value = int(per_function_cog[func_info.name])
			func_data["cog"] = cog_value
		var cc_bd = {}
		var cog_bd = {}
		if per_function_cc_breakdown.has(func_info.name):
			cc_bd = per_function_cc_breakdown[func_info.name]
			func_data["cc_breakdown"] = cc_bd
		if per_function_cog_breakdown.has(func_info.name):
			cog_bd = per_function_cog_breakdown[func_info.name]
			func_data["cog_breakdown"] = cog_bd
		if cc_bd.size() > 0 or cog_bd.size() > 0:
			func_data["why"] = explainer.explain_function(cc_value, cog_value, cc_bd, cog_bd)
		if bool(func_info.ignored):
			func_data["ignored"] = true
		if bool(func_info.pinned):
			func_data["pinned"] = true
		func_list.append(func_data)
	explainer = null
	return func_list

func _top_fixes_html(project_result, config) -> String:
	var builder = load(SRC_ROOT + "/core/top_fixes_builder.gd").new()
	var entries = builder.build(project_result, config, 10)
	builder = null
	var rows: Array = []
	rows.append("<h2>What to fix next</h2>")
	rows.append("<p>Open these first. Status: <span class=\"fix-soon\">Fix soon</span>, <span class=\"hard\">Hard to read</span>, <span class=\"pinned\">Pinned</span>.</p>")
	if entries.size() == 0:
		rows.append("<p>Nothing urgent — keep going.</p>")
		return "\n".join(rows)
	rows.append("<table><thead><tr>")
	rows.append("<th>What</th><th>Status</th><th class=\"num\">CC</th><th class=\"num\">C-COG</th><th>Why</th>")
	rows.append("</tr></thead><tbody>")
	for entry in entries:
		var path = str(entry.get("script_path", ""))
		var func_name = str(entry.get("function", ""))
		var label = str(entry.get("label", ""))
		var cls = "fix-soon" if label == "Fix soon" else ("hard" if label == "Hard to read" else "pinned")
		var what = "%s — %s()" % [path.get_file(), func_name]
		rows.append("<tr><td>%s</td><td class=\"%s\">%s</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"why\">%s</td></tr>" % [
			_html_escape(what),
			cls,
			_html_escape(label),
			int(entry.get("cc", 0)),
			int(entry.get("cog", 0)),
			_html_escape(str(entry.get("why", "")))
		])
	rows.append("</tbody></table>")
	return "\n".join(rows)

func _god_scripts_payload(project_result, config) -> Array:
	var rollup = load(SRC_ROOT + "/core/god_script_rollup.gd").new()
	var entries = rollup.build(project_result, config, 10)
	rollup = null
	return entries

func _churn_payload(god_scripts: Array, config) -> Array:
	var churn = load(SRC_ROOT + "/core/churn_hotspots.gd").new()
	var hot = churn.enrich(god_scripts, "res://", config, 5)
	churn = null
	return hot

func _god_scripts_html(project_result, config) -> String:
	var gods = _god_scripts_payload(project_result, config)
	var hot = _churn_payload(gods, config)
	var hot_paths = {}
	for h in hot:
		hot_paths[str(h.get("script_path", ""))] = h
	var rows: Array = []
	rows.append("<h2>Big scary files</h2>")
	rows.append("<p>Whole scripts that are huge, Fix soon at file totals, or both. <span class=\"hot\">Hot</span> means scary and recently changed in git (when available).</p>")
	if gods.size() == 0:
		rows.append("<p>No god-scripts spotted.</p>")
		return "\n".join(rows)
	rows.append("<table><thead><tr>")
	rows.append("<th>File</th><th>Status</th><th class=\"num\">CC</th><th class=\"num\">C-COG</th><th class=\"num\">LOC</th><th>Why</th>")
	rows.append("</tr></thead><tbody>")
	for entry in gods:
		var path = str(entry.get("script_path", ""))
		var label = str(entry.get("label", ""))
		var reason = str(entry.get("reason_text", ""))
		if hot_paths.has(path):
			label = "Hot"
			reason = str(hot_paths[path].get("reason_text", reason))
		var cls = "fix-soon"
		if label == "Hot":
			cls = "hot"
		elif label == "Hard to read":
			cls = "hard"
		rows.append("<tr><td>%s</td><td class=\"%s\">%s</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"why\">%s</td></tr>" % [
			_html_escape(path.get_file()),
			cls,
			_html_escape(label),
			int(entry.get("cc", 0)),
			int(entry.get("cog", 0)),
			int(entry.get("loc_code", 0)),
			_html_escape(reason)
		])
	rows.append("</tbody></table>")
	return "\n".join(rows)

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

func generate_html(project_result, config) -> String:
	var ts = Time.get_datetime_string_from_system()
	var parts: Array = []
	parts.append("<!DOCTYPE html>")
	parts.append("<html lang=\"en\"><head><meta charset=\"utf-8\">")
	parts.append("<title>GDMetrics Complexity Report</title>")
	parts.append("<style>")
	parts.append("body{font-family:system-ui,sans-serif;margin:1.5rem;color:#222;background:#fafafa}")
	parts.append("h1,h2{margin:0.6rem 0} table{border-collapse:collapse;width:100%;margin:1rem 0;background:#fff}")
	parts.append("th,td{border:1px solid #ccc;padding:0.4rem 0.6rem;text-align:left}")
	parts.append("th{background:#eee} .num{text-align:right} .totals{display:flex;gap:1.5rem;flex-wrap:wrap}")
	parts.append(".totals div{background:#fff;border:1px solid #ccc;padding:0.75rem 1rem;min-width:8rem}")
	parts.append(".chart{margin:1rem 0;background:#fff;border:1px solid #ccc;padding:1rem;overflow-x:auto}")
	parts.append(".fix-soon{color:#b33}.hard{color:#a80}.pinned{color:#356}.hot{color:#c65}.motto{font-size:1.1rem;margin:0.4rem 0 1rem}")
	parts.append(".why{color:#444;font-size:0.9rem}")
	parts.append("</style></head><body>")
	parts.append("<h1>GDMetrics Complexity Report</h1>")
	parts.append("<p class=\"motto\">Know what to fix before you hate the project.</p>")
	parts.append("<p>Generated %s</p>" % _html_escape(ts))
	parts.append("<div class=\"totals\">")
	parts.append("<div><strong>Files</strong><br>%d / %d ok</div>" % [
		project_result.successful_files, project_result.total_files
	])
	parts.append("<div><strong>Total CC</strong><br>%d</div>" % project_result.total_cc)
	parts.append("<div><strong>Total C-COG</strong><br>%d</div>" % project_result.total_cog)
	parts.append("<div><strong>Avg CC</strong><br>%.2f</div>" % project_result.average_cc)
	parts.append("<div><strong>Avg C-COG</strong><br>%.2f</div>" % project_result.average_cog)
	parts.append("</div>")

	parts.append(_top_fixes_html(project_result, config))
	parts.append(_god_scripts_html(project_result, config))

	parts.append("<h2>Top C-COG files</h2>")
	parts.append("<div class=\"chart\">")
	parts.append(_svg_cog_bars(project_result.worst_cog_files))
	parts.append("</div>")

	parts.append("<h2>Worst offenders (CC)</h2>")
	parts.append(_offender_table(project_result.worst_cc_files, "cc"))
	parts.append("<h2>Worst offenders (C-COG)</h2>")
	parts.append(_offender_table(project_result.worst_cog_files, "cog"))

	parts.append("<h2>Per-file metrics</h2>")
	parts.append("<table><thead><tr>")
	parts.append("<th>File</th><th class=\"num\">CC</th><th class=\"num\">C-COG</th>")
	parts.append("<th class=\"num\">Nest</th><th class=\"num\">Params</th><th class=\"num\">LOC</th>")
	parts.append("<th class=\"num\">Confidence</th></tr></thead><tbody>")
	for result in project_result.file_results:
		if not result.success:
			continue
		parts.append("<tr><td>%s</td><td class=\"num\">%d</td><td class=\"num\">%d</td>" % [
			_html_escape(str(result.file_path)), result.cc, result.cog
		])
		parts.append("<td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td>" % [
			result.max_nesting_depth, result.max_params, result.loc_code
		])
		parts.append("<td class=\"num\">%.2f</td></tr>" % result.confidence)
	parts.append("</tbody></table>")
	parts.append("</body></html>")
	return "\n".join(parts)

func write_html(html_text: String, output_path: String) -> bool:
	output_path = _sanitize_path(output_path)
	if not _check_output_overwrite(output_path):
		return false
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(html_text)
	file = null
	return true

func _html_escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

func _offender_table(file_results: Array, metric: String) -> String:
	var rows: Array = []
	rows.append("<table><thead><tr><th>File</th><th class=\"num\">%s</th><th class=\"num\">Confidence</th></tr></thead><tbody>" % metric.to_upper())
	for result in file_results:
		if not result.success:
			continue
		var value = result.cc if metric == "cc" else result.cog
		rows.append("<tr><td>%s</td><td class=\"num\">%d</td><td class=\"num\">%.2f</td></tr>" % [
			_html_escape(str(result.file_path)), value, result.confidence
		])
	rows.append("</tbody></table>")
	return "\n".join(rows)

func _svg_cog_bars(file_results: Array) -> String:
	var items: Array = []
	for result in file_results:
		if result.success:
			items.append(result)
		if items.size() >= 10:
			break
	if items.size() == 0:
		return "<p>No data</p>"
	var max_cog = 1
	for result in items:
		if result.cog > max_cog:
			max_cog = result.cog
	var bar_h = 18
	var gap = 6
	var label_w = 220
	var chart_w = 480
	var height = items.size() * (bar_h + gap) + 10
	var parts: Array = []
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [
		label_w + chart_w + 60, height, label_w + chart_w + 60, height
	])
	var i = 0
	for result in items:
		var y = i * (bar_h + gap) + 4
		var w = int(float(result.cog) / float(max_cog) * chart_w)
		var name = str(result.file_path).get_file()
		parts.append("<text x=\"0\" y=\"%d\" font-size=\"12\" dominant-baseline=\"middle\">%s</text>" % [
			y + bar_h / 2, _html_escape(name)
		])
		parts.append("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"#4a90d9\"/>" % [
			label_w, y, max(w, 1), bar_h
		])
		parts.append("<text x=\"%d\" y=\"%d\" font-size=\"12\" dominant-baseline=\"middle\">%d</text>" % [
			label_w + w + 6, y + bar_h / 2, result.cog
		])
		i += 1
	parts.append("</svg>")
	return "\n".join(parts)

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
		_error_codes = load(SRC_ROOT + "/core/error_codes.gd").new()
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

