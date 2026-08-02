extends Object

# Configuration manager
# handles JSON configuration parsing, validation, and defaults

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"

class Config:
	var include_patterns: Array = []
	var exclude_patterns: Array = []
	var cc_config: Dictionary = {}
	var cog_config: Dictionary = {}
	var structural_config: Dictionary = {}
	var parser_config: Dictionary = {}
	var report_config: Dictionary = {}
	var performance_config: Dictionary = {}
	var telemetry_config: Dictionary = {}
	var logging_config: Dictionary = {}
	
	func _init():
		include_patterns = ["res://**/*.gd"]
		exclude_patterns = [
			"res://.git/**",
			"res://.godot/**",
			"res://node_modules/**",
			"res://addons/gdscript_complexity/**",
			"res://addons/**/test/**",
			"res://tests/**",
			"res://cli/**",
			"res://examples/**"
		]
		cc_config = {
			"count_logical_operators": true,
			"threshold_warn": 10,
			"threshold_fail": 20
		}
		cog_config = {
			"nesting_penalty": 1,
			"threshold_warn": 15,
			"threshold_fail": 30
		}
		structural_config = {
			"nesting_warn": 3,
			"nesting_fail": 5,
			"params_warn": 4,
			"params_fail": 8,
			"loc_warn": 300,
			"loc_fail": 500
		}
		parser_config = {
			"prefer_ast_when_available": false,
			"fallback_to_heuristic": true,
			"parser_mode": "balanced",
			"max_expected_errors_per_100_lines": 5,
			"force_mode": null
		}
		report_config = {
			"formats": ["json"],
			"output_path": "res://complexity_report.json",
			"csv_output_path": "res://complexity_report.csv",
			"html_output_path": "res://complexity_report.html",
			"history_path": "complexity_history.jsonl",
			"auto_export": false,
			"annotate_editor": false,
			"churn_hotspots": "auto",
			"churn_since": "90 days ago",
			"god_complex_func_min": 3
		}
		performance_config = {
			"enable_caching": true,
			"cache_path": ".gdcomplexity_cache",
			"incremental_analysis": true,
			"enable_profiling": false
		}
		telemetry_config = {
			"enable_anonymous_reporting": false
		}
		logging_config = {
			"enable_console": true,
			"enable_file": false,
			"file_path": "res://complexity_analyzer.log",
			"level": "info"
		}

var config: Config
var config_path: String = ""
var errors: Array = []
var _file_helper = null
var _error_codes = null

func _init(config_file_path: String = ""):
	config = Config.new()
	_error_codes = load(SRC_ROOT + "/core/error_codes.gd").new()
	var _file_helper_script = load(SRC_ROOT + "/gd4/file_helper.gd")
	if _file_helper_script != null:
		_file_helper = _file_helper_script.new()
	if config_file_path != "":
		load_config(config_file_path)

func _ensure_file_helper():
	if _file_helper != null:
		return
	var helper_script = load(SRC_ROOT + "/gd4/file_helper.gd")
	if helper_script != null:
		_file_helper = helper_script.new()

func load_config(config_file_path: String) -> bool:
	errors.clear()
	config_path = config_file_path
	
	_ensure_file_helper()
	
	var json_text: String = ""
	
	if _file_helper == null:
		errors.append(_format_error("CONFIG_HELPER_MISSING", "File helper not available (using defaults)"))
		return false
	
	if not _file_helper.file_exists(config_file_path):
		errors.append(_format_error("CONFIG_FILE_NOT_FOUND", "Config file not found: %s (using defaults)" % config_file_path))
		return false
	
	var f = _file_helper.open_read(config_file_path)
	if f == null:
		errors.append(_format_error("CONFIG_OPEN_FAILED", "Failed to open config file: %s (using defaults)" % config_file_path))
		return false
	
	json_text = f.get_as_text()
	_file_helper.close_file(f)
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		errors.append(_format_error("CONFIG_INVALID_JSON", "Invalid JSON in config file: %s (using defaults)" % json.get_error_message()))
		return false
	
	var data = json.get_data()
	
	if not data is Dictionary:
		errors.append(_format_error("CONFIG_INVALID_ROOT", "Config file must contain a JSON object (using defaults)"))
		return false
	
	_parse_config(data)
	return true

func _parse_config(data: Dictionary):
	if data.has("include"):
		if data["include"] is Array:
			config.include_patterns = data["include"]
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'include' must be an array"))
	
	if data.has("exclude"):
		if data["exclude"] is Array:
			config.exclude_patterns = data["exclude"]
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'exclude' must be an array"))
	
	if data.has("cc"):
		if data["cc"] is Dictionary:
			_parse_cc_config(data["cc"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'cc' must be an object"))
	
	if data.has("cog"):
		if data["cog"] is Dictionary:
			_parse_cog_config(data["cog"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'cog' must be an object"))
	
	if data.has("structural"):
		if data["structural"] is Dictionary:
			_parse_structural_config(data["structural"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'structural' must be an object"))
	
	if data.has("parser"):
		if data["parser"] is Dictionary:
			_parse_parser_config(data["parser"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'parser' must be an object"))
	
	if data.has("report"):
		if data["report"] is Dictionary:
			_parse_report_config(data["report"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'report' must be an object"))
	
	if data.has("performance"):
		if data["performance"] is Dictionary:
			_parse_performance_config(data["performance"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'performance' must be an object"))
	
	if data.has("telemetry"):
		if data["telemetry"] is Dictionary:
			_parse_telemetry_config(data["telemetry"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'telemetry' must be an object"))
	
	if data.has("logging"):
		if data["logging"] is Dictionary:
			_parse_logging_config(data["logging"])
		else:
			errors.append(_format_error("CONFIG_INVALID_TYPE", "Config 'logging' must be an object"))

func _parse_cc_config(cc_data: Dictionary):
	if cc_data.has("count_logical_operators"):
		if cc_data["count_logical_operators"] is bool:
			config.cc_config["count_logical_operators"] = cc_data["count_logical_operators"]
	
	if cc_data.has("threshold_warn"):
		var v = cc_data["threshold_warn"]
		if (v is int or v is float) and int(v) >= 0:
			config.cc_config["threshold_warn"] = int(v)
	
	if cc_data.has("threshold_fail"):
		var v = cc_data["threshold_fail"]
		if (v is int or v is float) and int(v) >= 0:
			config.cc_config["threshold_fail"] = int(v)

func _parse_cog_config(cog_data: Dictionary):
	if cog_data.has("nesting_penalty"):
		var v = cog_data["nesting_penalty"]
		if (v is int or v is float) and int(v) >= 0:
			config.cog_config["nesting_penalty"] = int(v)
	
	if cog_data.has("threshold_warn"):
		var v = cog_data["threshold_warn"]
		if (v is int or v is float) and int(v) >= 0:
			config.cog_config["threshold_warn"] = int(v)
	
	if cog_data.has("threshold_fail"):
		var v = cog_data["threshold_fail"]
		if (v is int or v is float) and int(v) >= 0:
			config.cog_config["threshold_fail"] = int(v)

func _parse_structural_config(structural_data: Dictionary):
	for key in ["nesting_warn", "nesting_fail", "params_warn", "params_fail", "loc_warn", "loc_fail"]:
		if structural_data.has(key):
			var v = structural_data[key]
			if (v is int or v is float) and int(v) >= 0:
				config.structural_config[key] = int(v)

func _parse_parser_config(parser_data: Dictionary):
	if parser_data.has("prefer_ast_when_available"):
		if parser_data["prefer_ast_when_available"] is bool:
			config.parser_config["prefer_ast_when_available"] = parser_data["prefer_ast_when_available"]
	
	if parser_data.has("fallback_to_heuristic"):
		if parser_data["fallback_to_heuristic"] is bool:
			config.parser_config["fallback_to_heuristic"] = parser_data["fallback_to_heuristic"]
	
	if parser_data.has("parser_mode"):
		if parser_data["parser_mode"] is String:
			var mode = parser_data["parser_mode"]
			if mode == "fast" or mode == "balanced" or mode == "thorough":
				config.parser_config["parser_mode"] = mode
			else:
				errors.append(_format_error("CONFIG_INVALID_VALUE", "Invalid parser_mode '%s', using 'balanced'" % mode))
	
	if parser_data.has("max_expected_errors_per_100_lines"):
		if parser_data["max_expected_errors_per_100_lines"] is int and parser_data["max_expected_errors_per_100_lines"] >= 0:
			config.parser_config["max_expected_errors_per_100_lines"] = parser_data["max_expected_errors_per_100_lines"]
	
	if parser_data.has("force_mode"):
		if parser_data["force_mode"] == null:
			config.parser_config["force_mode"] = null
		elif parser_data["force_mode"] is String:
			var mode = parser_data["force_mode"]
			if mode == "fast" or mode == "balanced" or mode == "thorough":
				config.parser_config["force_mode"] = mode
			else:
				errors.append(_format_error("CONFIG_INVALID_VALUE", "Invalid force_mode '%s', using null" % mode))
	
	if parser_data.has("confidence_weights"):
		if parser_data["confidence_weights"] is Dictionary:
			config.parser_config["confidence_weights"] = parser_data["confidence_weights"]

func _parse_report_config(report_data: Dictionary):
	if report_data.has("formats"):
		if report_data["formats"] is Array:
			config.report_config["formats"] = report_data["formats"]
	
	if report_data.has("output_path"):
		if report_data["output_path"] is String:
			config.report_config["output_path"] = report_data["output_path"]
	
	if report_data.has("csv_output_path"):
		if report_data["csv_output_path"] is String:
			config.report_config["csv_output_path"] = report_data["csv_output_path"]
	
	if report_data.has("html_output_path"):
		if report_data["html_output_path"] is String:
			config.report_config["html_output_path"] = report_data["html_output_path"]
	
	if report_data.has("auto_export"):
		if report_data["auto_export"] is bool:
			config.report_config["auto_export"] = report_data["auto_export"]
	
	if report_data.has("annotate_editor"):
		if report_data["annotate_editor"] is bool:
			config.report_config["annotate_editor"] = report_data["annotate_editor"]

	if report_data.has("history_path"):
		if report_data["history_path"] is String:
			config.report_config["history_path"] = report_data["history_path"]

	if report_data.has("churn_hotspots"):
		config.report_config["churn_hotspots"] = str(report_data["churn_hotspots"])

	if report_data.has("churn_since"):
		if report_data["churn_since"] is String:
			config.report_config["churn_since"] = report_data["churn_since"]

	if report_data.has("god_complex_func_min"):
		config.report_config["god_complex_func_min"] = int(report_data["god_complex_func_min"])

func _parse_performance_config(perf_data: Dictionary):
	if perf_data.has("enable_caching"):
		if perf_data["enable_caching"] is bool:
			config.performance_config["enable_caching"] = perf_data["enable_caching"]
	
	if perf_data.has("cache_path"):
		if perf_data["cache_path"] is String:
			config.performance_config["cache_path"] = perf_data["cache_path"]
	
	if perf_data.has("incremental_analysis"):
		if perf_data["incremental_analysis"] is bool:
			config.performance_config["incremental_analysis"] = perf_data["incremental_analysis"]
	
	if perf_data.has("enable_profiling"):
		if perf_data["enable_profiling"] is bool:
			config.performance_config["enable_profiling"] = perf_data["enable_profiling"]

func _parse_telemetry_config(telemetry_data: Dictionary):
	if telemetry_data.has("enable_anonymous_reporting"):
		if telemetry_data["enable_anonymous_reporting"] is bool:
			config.telemetry_config["enable_anonymous_reporting"] = telemetry_data["enable_anonymous_reporting"]

func _parse_logging_config(logging_data: Dictionary):
	if logging_data.has("enable_console"):
		if logging_data["enable_console"] is bool:
			config.logging_config["enable_console"] = logging_data["enable_console"]
	
	if logging_data.has("enable_file"):
		if logging_data["enable_file"] is bool:
			config.logging_config["enable_file"] = logging_data["enable_file"]
	
	if logging_data.has("file_path"):
		if logging_data["file_path"] is String:
			config.logging_config["file_path"] = logging_data["file_path"]
	
	if logging_data.has("level"):
		if logging_data["level"] is String:
			config.logging_config["level"] = logging_data["level"].to_lower()

func get_include_patterns() -> Array:
	return config.include_patterns.duplicate()

func get_exclude_patterns() -> Array:
	return config.exclude_patterns.duplicate()

func get_cc_threshold_warn() -> int:
	return config.cc_config["threshold_warn"]

func get_cc_threshold_fail() -> int:
	return config.cc_config["threshold_fail"]

func get_cog_threshold_warn() -> int:
	return config.cog_config["threshold_warn"]

func get_cog_threshold_fail() -> int:
	return config.cog_config["threshold_fail"]

func get_parser_mode() -> String:
	return config.parser_config["parser_mode"]

func get_force_mode():
	return config.parser_config["force_mode"]

func get_config() -> Config:
	return config

func get_errors() -> Array:
	return errors.duplicate()

func has_errors() -> bool:
	return errors.size() > 0

func _format_error(code: String, detail: String) -> String:
	if _error_codes == null:
		return "[%s] %s" % [code, detail]
	return _error_codes.format(code, detail)

