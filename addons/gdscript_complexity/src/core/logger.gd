# Logging helper with levels and optional file output.

extends Object

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"
const CORE_ROOT := SRC_ROOT + "/core"

const LEVEL_ERROR = "error"
const LEVEL_WARNING = "warning"
const LEVEL_INFO = "info"
const LEVEL_DEBUG = "debug"

var enable_console: bool = true
var enable_file: bool = false
var file_path: String = "res://complexity_analyzer.log"
var level: String = LEVEL_INFO

var _file_helper = null
var _time_helper = null
var _time_helper_path: String = ""

var _level_order = {
	LEVEL_ERROR: 0,
	LEVEL_WARNING: 1,
	LEVEL_INFO: 2,
	LEVEL_DEBUG: 3
}

func configure(logging_config: Dictionary) -> void:
	if logging_config == null:
		return
	if logging_config.has("enable_console"):
		enable_console = logging_config["enable_console"]
	if logging_config.has("enable_file"):
		enable_file = logging_config["enable_file"]
	if logging_config.has("file_path"):
		file_path = logging_config["file_path"]
	if logging_config.has("level"):
		level = str(logging_config["level"]).to_lower()

func log_message(level_name: String, message: String) -> void:
	if not _should_log(level_name):
		return
	var formatted = _format_message(level_name, message)
	if enable_console:
		_log_console(level_name, formatted)
	if enable_file:
		_append_file(formatted)

func log_with_code(level_name: String, code: String, message: String) -> void:
	var error_codes = _get_error_codes()
	var formatted = error_codes.format(code, message)
	log_message(level_name, formatted)

func _should_log(level_name: String) -> bool:
	var target = _level_order.get(level_name.to_lower(), 2)
	var current = _level_order.get(level.to_lower(), 2)
	return target <= current

func _format_message(level_name: String, message: String) -> String:
	return "[ComplexityAnalyzer] [%s] %s" % [level_name.to_upper(), message]

func _log_console(level_name: String, message: String) -> void:
	if level_name == LEVEL_ERROR:
		push_error(message)
	else:
		print(message)

func _append_file(message: String) -> void:
	var helper = _ensure_file_helper()
	if helper == null:
		return
	var file = helper.open_append(file_path)
	if file == null:
		return
	var line = "%s %s" % [_get_timestamp(), message]
	helper.write_line(file, line)
	helper.close_file(file)

func _ensure_file_helper():
	if _file_helper != null:
		return _file_helper
	var major = Engine.get_version_info().get("major", 0)
	var helper_script = SRC_ROOT + "/gd4/file_helper.gd"
	if major < 4:
		helper_script = SRC_ROOT + "/gd3/file_helper.gd"
	var helper_resource = load(helper_script)
	if helper_resource != null:
		_file_helper = helper_resource.new()
	return _file_helper

func _get_error_codes():
	return load(CORE_ROOT + "/error_codes.gd").new()

func _get_timestamp() -> String:
	var helper = _ensure_time_helper()
	if helper == null:
		return ""
	return helper.get_timestamp()

func _ensure_time_helper():
	if _time_helper != null:
		return _time_helper
	var major = Engine.get_version_info().get("major", 0)
	_time_helper_path = SRC_ROOT + "/gd4/time_helper.gd"
	if major < 4:
		_time_helper_path = SRC_ROOT + "/gd3/time_helper.gd"
	var helper_resource = load(_time_helper_path)
	if helper_resource == null:
		return null
	_time_helper = helper_resource.new()
	_debug_time_helper()
	return _time_helper

func _debug_time_helper():
	if Engine.is_editor_hint():
		print("[ComplexityAnalyzer] Time helper: %s" % _time_helper_path)
