extends Object
# class_name BatchAnalyzer  # Commented out to avoid parse-time cascade

# Batch analyzer
# processes multiple files and aggregates results

const ADDON_SRC := "res://addons/gdscript_complexity/src/"

class FileResult:
	var file_path: String = ""
	var success: bool = false
	var cc: int = 0
	var cog: int = 0
	var confidence: float = 0.0
	var functions: Array = []
	var classes: Array = []
	var errors: Array = []
	var cc_breakdown: Dictionary = {}
	var cog_breakdown: Dictionary = {}
	var per_function_cc: Dictionary = {}
	var per_function_cog: Dictionary = {}
	var max_nesting_depth: int = 0
	var match_arm_count: int = 0
	var lambda_count: int = 0
	var loc_code: int = 0
	var max_params: int = 0

class ProjectResult:
	var total_files: int = 0
	var successful_files: int = 0
	var failed_files: int = 0
	var total_cc: int = 0
	var total_cog: int = 0
	var average_cc: float = 0.0
	var average_cog: float = 0.0
	var average_confidence: float = 0.0
	var worst_cc_files: Array = []
	var worst_cog_files: Array = []
	var file_results: Array = []
	var errors: Array = []
	var error_summary: Dictionary = {}
	var error_severity_summary: Dictionary = {}
	var total_errors: int = 0
	var performance: Dictionary = {}

var project_result = null  # ProjectResult - nested class
var version_adapter = null
var cache_manager = null
var logger = null
var _error_codes = null
var _tools_ready: bool = false
var _tokenizer_class = null
var _detector_instance = null
var _function_detector_instance = null
var _class_detector_instance = null
var _cc_calc_instance = null
var _cog_calc_instance = null
var _confidence_calc_instance = null
var _time_helper = null
var _time_helper_path: String = ""

func analyze_project(root_path: String, config, adapter = null):  # -> ProjectResult - nested class
	project_result = ProjectResult.new()
	version_adapter = adapter
	_error_codes = load(ADDON_SRC + "error_codes.gd").new()
	_ensure_logger(config)
	project_result.performance = {}
	var profiling = false
	if config.performance_config.has("enable_profiling"):
		profiling = config.performance_config["enable_profiling"]
	var total_start = _now_msec()
	
	# Initialize cache manager if caching is enabled
	if config.performance_config.get("enable_caching", false):
		var cache_path = config.performance_config.get("cache_path", ".gdcomplexity_cache")
		cache_manager = load(ADDON_SRC + "cache_manager.gd").new(cache_path, true)
	else:
		cache_manager = null
	
	var discovery_script = ADDON_SRC + "gd4/file_discovery.gd"
	var discovery = load(discovery_script).new()
	var files = discovery.find_files(root_path, config.include_patterns, config.exclude_patterns)
	
	project_result.total_files = files.size()
	
	if files.size() == 0:
		project_result.errors.append(_error_codes.format("NO_FILES_FOUND", "No files found matching include patterns"))
		_log_error("NO_FILES_FOUND", "No files found matching include patterns")
		return project_result
	
	# Cleanup orphaned cache entries if caching is enabled
	if cache_manager != null:
		cache_manager.cleanup_orphaned_entries(files)
	
	var file_results: Array = []
	var total_cc = 0
	var total_cog = 0
	var total_confidence = 0.0
	var successful_count = 0
	
	for i in range(files.size()):
		var file_path = files[i]
		var file_start = _now_msec()
		var file_result = _analyze_file(file_path, config, profiling)
		if profiling:
			_accumulate_perf("total_ms", _now_msec() - file_start)
		file_results.append(file_result)
		
		if file_result.success:
			successful_count += 1
			total_cc += file_result.cc
			total_cog += file_result.cog
			total_confidence += file_result.confidence
	
	project_result.successful_files = successful_count
	project_result.failed_files = files.size() - successful_count
	project_result.total_cc = total_cc
	project_result.total_cog = total_cog
	
	if successful_count > 0:
		project_result.average_cc = float(total_cc) / float(successful_count)
		project_result.average_cog = float(total_cog) / float(successful_count)
		project_result.average_confidence = float(total_confidence) / float(successful_count)
	
	project_result.file_results = file_results
	_set_error_summary(file_results)
	
	_calculate_worst_offenders(file_results)
	if profiling:
		_accumulate_perf("total_run_ms", _now_msec() - total_start)
	_reset_tools()
	
	return project_result

func _get_tokenizer_script() -> String:
	return ADDON_SRC + "tokenizer.gd"

func _ensure_tools():
	if _tools_ready:
		return
	_tokenizer_class = load(_get_tokenizer_script())
	_detector_instance = load(ADDON_SRC + "control_flow_detector.gd").new()
	_function_detector_instance = load(ADDON_SRC + "function_detector.gd").new()
	_class_detector_instance = load(ADDON_SRC + "class_detector.gd").new()
	_cc_calc_instance = load(ADDON_SRC + "cc_calculator.gd").new()
	_cog_calc_instance = load(ADDON_SRC + "cog_complexity_calculator.gd").new()
	_confidence_calc_instance = load(ADDON_SRC + "confidence_calculator.gd").new()
	_tools_ready = true

func _analyze_file(file_path: String, config, profiling: bool = false):  # -> FileResult - nested class
	var result = FileResult.new()
	result.file_path = file_path
	_ensure_tools()
	
	# Try to load from cache first
	if cache_manager != null:
		var cached_data = cache_manager.get_cached_result(file_path, config)
		if cached_data.size() > 0:
			# Cache hit - restore result from cache
			result = _restore_file_result_from_cache(cached_data)
			return result
	
	# Cache miss or caching disabled - perform full analysis
	var tokenizer = _tokenizer_class.new()
	var t0 = _now_msec()
	var tokens = tokenizer.tokenize_file(file_path)
	if profiling:
		_accumulate_perf("tokenize_ms", _now_msec() - t0)
	var tokenizer_errors = tokenizer.get_errors()
	
	if tokenizer_errors.size() > 0 and tokens.size() == 0:
		result.errors = tokenizer_errors
		result.success = false
		_log_error("TOKEN_PARSE_ERROR", "Tokenization failed for %s" % file_path)
		# Store failed result in cache (so we don't retry failed files)
		if cache_manager != null:
			cache_manager.store_result(file_path, config, result)
		return result
	
	if tokenizer_errors.size() > 0:
		# Partial tokenize success â€” keep going; confidence will reflect errors
		result.errors = tokenizer_errors
		_log_warning("TOKEN_PARSE_ERROR", "Tokenizer warnings for %s (%d)" % [file_path, tokenizer_errors.size()])
	
	if tokens.size() == 0:
		# Empty / whitespace-only file is a successful zero-complexity analysis
		result.success = true
		result.cc = 0
		result.cog = 0
		result.confidence = version_adapter.get_confidence_cap() if version_adapter != null else 1.0
		result.loc_code = 0
		if cache_manager != null:
			cache_manager.store_result(file_path, config, result)
		return result
	
	var d0 = _now_msec()
	var control_flow_nodes = _detector_instance.detect_control_flow(tokens, version_adapter)
	var detector_errors = _detector_instance.get_errors()
	if detector_errors.size() > 0:
		result.errors += detector_errors
	
	var functions = _function_detector_instance.detect_functions(tokens)
	result.functions = functions
	
	var classes = _class_detector_instance.detect_classes(tokens)
	result.classes = classes
	var class_errors = _class_detector_instance.get_errors()
	if class_errors.size() > 0:
		result.errors += class_errors
	if profiling:
		_accumulate_perf("detect_ms", _now_msec() - d0)
	
	var c0 = _now_msec()
	var count_logical = true
	if config != null and config.cc_config.has("count_logical_operators"):
		count_logical = config.cc_config["count_logical_operators"]
	var cc = _cc_calc_instance.calculate_cc(control_flow_nodes, count_logical)
	result.cc = cc
	result.cc_breakdown = _cc_calc_instance.get_breakdown()
	result.per_function_cc = _calculate_per_function_cc(control_flow_nodes, functions)
	
	var cog_result = _cog_calc_instance.calculate_cog(control_flow_nodes, functions)
	result.cog = cog_result.total_cog
	result.cog_breakdown = cog_result.breakdown
	result.per_function_cog = cog_result.per_function

	_fill_extra_metrics(result, control_flow_nodes, functions, tokens)
	
	var confidence_weights = {}
	if config.parser_config.has("confidence_weights"):
		confidence_weights = config.parser_config["confidence_weights"]
	var confidence_result = _confidence_calc_instance.calculate_confidence(tokens, tokenizer_errors, version_adapter, confidence_weights)
	result.confidence = confidence_result.score
	if profiling:
		_accumulate_perf("calc_ms", _now_msec() - c0)
	
	result.success = true
	
	# Store successful result in cache
	if cache_manager != null:
		cache_manager.store_result(file_path, config, result)
	
	return result

# Restore FileResult from cached dictionary data
func _restore_file_result_from_cache(cached_data: Dictionary) -> FileResult:
	var result = FileResult.new()
	result.file_path = cached_data.get("file_path", "")
	result.success = cached_data.get("success", false)
	result.cc = cached_data.get("cc", 0)
	result.cog = cached_data.get("cog", 0)
	result.confidence = cached_data.get("confidence", 0.0)
	result.functions = cached_data.get("functions", [])
	result.classes = cached_data.get("classes", [])
	result.errors = cached_data.get("errors", [])
	result.cc_breakdown = cached_data.get("cc_breakdown", {})
	result.cog_breakdown = cached_data.get("cog_breakdown", {})
	result.per_function_cc = cached_data.get("per_function_cc", {})
	result.per_function_cog = cached_data.get("per_function_cog", {})
	return result

func _calculate_per_function_cc(control_flow_nodes: Array, functions: Array) -> Dictionary:
	var per_function = {}
	if functions.size() == 0:
		return per_function
	
	for func_info in functions:
		var func_nodes: Array = []
		for node in control_flow_nodes:
			if node.line >= func_info.start_line and node.line <= func_info.end_line:
				func_nodes.append(node)
		
		var func_cc = _cc_calc_instance.calculate_cc(func_nodes, true)
		per_function[func_info.name] = func_cc
	
	return per_function

func _fill_extra_metrics(result: FileResult, control_flow_nodes: Array, functions: Array, tokens: Array) -> void:
	var max_depth = 0
	var arms = 0
	var lambdas = 0
	for node in control_flow_nodes:
		if node.depth > max_depth:
			max_depth = node.depth
		if node.type == "case":
			arms += 1
		elif node.type == "lambda":
			lambdas += 1
	result.max_nesting_depth = max_depth
	result.match_arm_count = arms
	result.lambda_count = lambdas

	var max_params = 0
	for func_info in functions:
		var pc = 0
		if func_info.parameters != null:
			pc = func_info.parameters.size()
		if pc > max_params:
			max_params = pc
	result.max_params = max_params

	# LOC: distinct lines that have a non-whitespace, non-comment token
	var TokenType = load(ADDON_SRC + "tokenizer.gd").TokenType
	var code_lines = {}
	for token in tokens:
		if token.type == TokenType.WHITESPACE or token.type == TokenType.COMMENT or token.type == TokenType.NEWLINE:
			continue
		code_lines[token.line] = true
	result.loc_code = code_lines.size()

func _reset_tools():
	_tokenizer_class = null
	_detector_instance = null
	_function_detector_instance = null
	_class_detector_instance = null
	_cc_calc_instance = null
	_cog_calc_instance = null
	_confidence_calc_instance = null
	_tools_ready = false

func _accumulate_perf(key: String, value: int) -> void:
	if not project_result.performance.has(key):
		project_result.performance[key] = 0
	project_result.performance[key] += value

func _now_msec() -> int:
	var helper = _ensure_time_helper()
	if helper == null:
		return 0
	return helper.get_msec()

func _ensure_time_helper():
	if _time_helper != null:
		return _time_helper
	_time_helper_path = ADDON_SRC + "gd4/time_helper.gd"
	var helper_resource = load(_time_helper_path)
	if helper_resource == null:
		return null
	_time_helper = helper_resource.new()
	_debug_time_helper()
	return _time_helper

func _debug_time_helper():
	if Engine.is_editor_hint():
		print("[ComplexityAnalyzer] Batch time helper: %s" % _time_helper_path)

func _calculate_worst_offenders(file_results: Array):
	var cc_sorted = []
	var cog_sorted = []
	
	for result in file_results:
		if result.success:
			cc_sorted.append(result)
			cog_sorted.append(result)
	
	_sort_by_cc(cc_sorted)
	_sort_by_cog(cog_sorted)
	
	project_result.worst_cc_files = cc_sorted.slice(0, min(10, cc_sorted.size()))
	project_result.worst_cog_files = cog_sorted.slice(0, min(10, cog_sorted.size()))

func _sort_by_cc(arr: Array):
	var n = arr.size()
	var i = 0
	while i < n:
		var best = i
		var j = i + 1
		while j < n:
			if arr[j].cc > arr[best].cc:
				best = j
			j += 1
		if best != i:
			var tmp = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp
		i += 1

func _sort_by_cog(arr: Array):
	var n = arr.size()
	var i = 0
	while i < n:
		var best = i
		var j = i + 1
		while j < n:
			if arr[j].cog > arr[best].cog:
				best = j
			j += 1
		if best != i:
			var tmp = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp
		i += 1

func get_project_result():  # -> ProjectResult - nested class
	return project_result

func _ensure_logger(config):
	if logger != null:
		return
	logger = load(ADDON_SRC + "logger.gd").new()
	if config != null and config.logging_config != null:
		logger.configure(config.logging_config)

func _log_error(code: String, message: String):
	if logger == null:
		return
	logger.log_with_code("error", code, message)

func _log_warning(code: String, message: String):
	if logger == null:
		return
	logger.log_with_code("warning", code, message)

func _set_error_summary(file_results: Array):
	var helper = load(ADDON_SRC + "error_summary.gd").new()
	var summary = helper.summarize(file_results, project_result.errors)
	project_result.error_summary = summary.by_code
	project_result.error_severity_summary = summary.by_severity
	project_result.total_errors = summary.total

# Helper methods to create nested class instances when class_name is commented out
static func create_file_result():  # -> FileResult - nested class
	return FileResult.new()

static func create_project_result():  # -> ProjectResult - nested class
	return ProjectResult.new()


