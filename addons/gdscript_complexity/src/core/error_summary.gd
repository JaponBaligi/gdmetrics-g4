# Error summary builder for reports and telemetry.

extends Object

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"
const CORE_ROOT := SRC_ROOT + "/core"

func summarize(file_results: Array, project_errors: Array = []) -> Dictionary:
	var by_code: Dictionary = {}
	var by_severity: Dictionary = {}
	var total = 0
	var codes = load(CORE_ROOT + "/error_codes.gd").new()
	
	for msg in project_errors:
		var code = _extract_code(msg)
		_increment(by_code, code)
		_increment(by_severity, codes.get_severity(code))
		total += 1
	
	for result in file_results:
		if result == null:
			continue
		for msg in result.errors:
			var code = _extract_code(msg)
			_increment(by_code, code)
			_increment(by_severity, codes.get_severity(code))
			total += 1
	
	return {
		"by_code": by_code,
		"by_severity": by_severity,
		"total": total
	}

func _extract_code(message: String) -> String:
	if message.begins_with("["):
		var end = message.find("]")
		if end > 1:
			return message.substr(1, end - 1)
	return "UNKNOWN"

func _increment(target: Dictionary, key: String) -> void:
	if target.has(key):
		target[key] += 1
	else:
		target[key] = 1
