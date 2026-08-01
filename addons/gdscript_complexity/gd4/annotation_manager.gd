@tool
extends RefCounted

# Adds complexity warnings to script editor

var script_editor: Object = null
var has_annotation_support: bool = false
var annotation_api: String = "none" 
var version_adapter = null  # VersionAdapter - loaded dynamically
var _supported_severities = ["error", "warning", "info"]

func _init(adapter = null):  # VersionAdapter - loaded dynamically
	version_adapter = adapter
	_detect_annotation_support()

func _detect_annotation_support():
	if not Engine.is_editor_hint():
		has_annotation_support = false
		annotation_api = "none"
		return
	
	var editor_interface = EditorInterface
	if editor_interface == null:
		has_annotation_support = false
		annotation_api = "none"
		return
	
	script_editor = editor_interface.get_script_editor()
	if script_editor == null:
		has_annotation_support = false
		annotation_api = "none"
		return

	if script_editor.has_method("add_error_annotation"):
		has_annotation_support = true
		annotation_api = "add_error_annotation"
		return

	has_annotation_support = false
	annotation_api = "none"
	print("[ComplexityAnalyzer] No annotation API available (add_error_annotation not exposed by this editor build)")

func add_complexity_annotation(script_path: String, line: int, message: String, severity: String = "warning"):
	severity = _normalize_severity(severity)
	if script_path == "" or line < 1:
		_fallback_log(script_path, line, "Invalid annotation target", "warning")
		return
	if not has_annotation_support:
		_fallback_log(script_path, line, message, severity)
		return
	
	if script_editor == null:
		_fallback_log(script_path, line, message, severity)
		return
	
	if annotation_api == "add_error_annotation":
		_add_error_annotation_4x(script_path, line, message, severity)
	else:
		_fallback_log(script_path, line, message, severity)

func _add_error_annotation_4x(script_path: String, line: int, message: String, severity: String):
	if not script_editor.has_method("add_error_annotation"):
		_fallback_log(script_path, line, message, severity)
		return
	
	var severity_enum = 0
	if severity == "error":
		severity_enum = 0
	elif severity == "warning":
		severity_enum = 1
	else:
		severity_enum = 2
	
	script_editor.add_error_annotation(script_path, line, severity_enum, message)

func add_cc_warning(script_path: String, line: int, cc_value: int, threshold: int):
	var message = "High Cyclomatic Complexity: %d (threshold: %d)" % [cc_value, threshold]
	add_complexity_annotation(script_path, line, message, "warning")

func add_cog_warning(script_path: String, line: int, cog_value: int, threshold: int):
	var message = "High Cognitive Complexity: %d (threshold: %d)" % [cog_value, threshold]
	add_complexity_annotation(script_path, line, message, "warning")

func annotate_file_results(file_result, cc_threshold: int, cog_threshold: int):  # BatchAnalyzer.FileResult - loaded dynamically
	if not file_result.success:
		return
	
	var script_path = file_result.file_path
	
	if file_result.cc > cc_threshold:
		add_cc_warning(script_path, 1, file_result.cc, cc_threshold)
	
	if file_result.cog > cog_threshold:
		add_cog_warning(script_path, 1, file_result.cog, cog_threshold)
	
	for func_info in file_result.functions:
		if file_result.per_function_cog.has(func_info.name):
			var cog = file_result.per_function_cog[func_info.name]
			if cog > cog_threshold:
				add_cog_warning(script_path, func_info.start_line, cog, cog_threshold)

func clear_annotations(script_path: String):
	if not has_annotation_support or script_editor == null:
		return
	
	if annotation_api == "add_error_annotation" and script_editor.has_method("clear_annotations"):
		script_editor.clear_annotations(script_path)
	else:
		_fallback_log(script_path, 1, "clear_annotations not supported", "info")

func _fallback_log(script_path: String, line: int, message: String, severity: String):
	var log_message = "[ComplexityAnalyzer] %s:%d - %s: %s" % [script_path, line, severity.to_upper(), message]
	if severity == "error":
		push_error(log_message)
	else:
		print(log_message)

func is_supported() -> bool:
	return has_annotation_support

func get_annotation_api() -> String:
	return annotation_api

func _normalize_severity(severity: String) -> String:
	if _supported_severities.has(severity):
		return severity
	return "warning"
