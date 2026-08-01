# Parser stability validation
# Run with: godot --headless --script tests/validate_parser_stability.gd -- --project-path .

extends SceneTree

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"

class ValidationResult:
	var passed: bool = false
	var errors: Array = []
	var warnings: Array = []
	var stats: Dictionary = {}
	
	func _init():
		stats = {
			"total_files": 0,
			"successful_parses": 0,
			"failed_parses": 0,
			"error_rate": 0.0,
			"crash_count": 0,
			"indentation_issues": 0,
			"large_file_time": 0.0,
			"deep_nesting_time": 0.0,
			"edge_case_count": 0,
			"performance_avg_time": 0.0
		}

var result: ValidationResult

func _write_file(file_path: String, content: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file = null
	return true

func _read_file(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file = null
	return content

func _file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

func _remove_file(file_path: String):
	# Directory.remove/DirAccess.remove expect path relative to opened dir.
	# We use user://, so pass basename only (e.g. "user://temp_test_0.gd" -> "temp_test_0.gd").
	var name_in_user = file_path
	if file_path.begins_with("user://"):
		name_in_user = file_path.substr(7)
	
	var dir = DirAccess.open("user://")
	if dir != null:
		dir.remove(name_in_user)

func _get_ticks_msec() -> int:
	return Time.get_ticks_msec()

func _initialize():
	var args = OS.get_cmdline_args()
	var project_path = "."
	
	var dash_index = args.find("--")
	if dash_index >= 0:
		var remaining_args = []
		for i in range(dash_index + 1, args.size()):
			remaining_args.append(args[i])
		var i = 0
		while i < remaining_args.size():
			var arg = remaining_args[i]
			if arg == "--project-path" and i + 1 < remaining_args.size():
				project_path = remaining_args[i + 1]
				i += 2
			else:
				i += 1
	
	result = ValidationResult.new()
	var exit_code = validate_parser_stability(project_path)
	call_deferred("quit", exit_code)

func validate_parser_stability(project_path: String) -> int:
	print("=== Parser Stability Validation ===")
	print("")
	
	var all_passed = true

	print("Test 1: Multi-file analysis...")
	if not test_multi_file_analysis(project_path):
		all_passed = false

	print("")
	print("Test 2: Error rate validation...")
	if not test_error_rate():
		all_passed = false

	print("")
	print("Test 3: Stability (malformed input)...")
	if not test_stability():
		all_passed = false

	print("")
	print("Test 4: Indentation ambiguity handling...")
	if not test_indentation_ambiguity():
		all_passed = false

	print("")
	print("Test 5: JSON report generation...")
	if not test_json_output(project_path):
		all_passed = false

	print("")
	print("Test 6: Large file handling...")
	if not test_large_file_handling():
		all_passed = false

	print("")
	print("Test 7: Deeply nested code...")
	if not test_deeply_nested_code():
		all_passed = false

	print("")
	print("Test 8: Edge cases...")
	if not test_edge_cases():
		all_passed = false

	print("")
	print("Test 9: Performance benchmarks...")
	if not test_performance_benchmarks():
		all_passed = false

	print("")
	print("=== Validation Summary ===")
	print("Total files tested: %d" % result.stats["total_files"])
	print("Successful parses: %d" % result.stats["successful_parses"])
	print("Failed parses: %d" % result.stats["failed_parses"])
	print("Error rate: %.2f%%" % (result.stats["error_rate"] * 100))
	print("Crashes: %d" % result.stats["crash_count"])
	print("Indentation issues: %d" % result.stats["indentation_issues"])
	print("Edge cases tested: %d" % result.stats["edge_case_count"])
	if result.stats["large_file_time"] > 0:
		print("Large file parse time: %.3f seconds" % result.stats["large_file_time"])
	if result.stats["deep_nesting_time"] > 0:
		print("Deep nesting parse time: %.3f seconds" % result.stats["deep_nesting_time"])
	if result.stats["performance_avg_time"] > 0:
		print("Average parse time: %.3f seconds" % result.stats["performance_avg_time"])
	
	if result.errors.size() > 0:
		print("")
		print("Errors:")
		for error in result.errors:
			print("  - %s" % error)
	
	if result.warnings.size() > 0:
		print("")
		print("Warnings:")
		for warning in result.warnings:
			print("  - %s" % warning)
	
	print("")
	if all_passed and result.stats["error_rate"] < 0.10 and result.stats["crash_count"] == 0:
		print("++ Parser stability validation PASSED")
		return 0
	else:
		print("xx Parser stability validation FAILED")
		return 1

func test_multi_file_analysis(project_path: String) -> bool:
	var config_script = load(SRC_ROOT + "/config_manager.gd")
	assert(config_script != null, "Failed to load config_manager.gd")
	var config = config_script.new()
	var default_config = config.get_config()
	
	var batch_analyzer_script = load(SRC_ROOT + "/batch_analyzer.gd")
	assert(batch_analyzer_script != null, "Failed to load batch_analyzer.gd")
	var batch_analyzer = batch_analyzer_script.new()
	var project_result = batch_analyzer.analyze_project(project_path, default_config)
	
	result.stats["total_files"] = project_result.total_files
	result.stats["successful_parses"] = project_result.successful_files
	result.stats["failed_parses"] = project_result.failed_files
	
	if project_result.total_files == 0:
		result.errors.append("No files found for analysis")
		return false
	
	if project_result.successful_files == 0:
		result.errors.append("No files successfully analyzed")
		return false
	
	var success_rate = float(project_result.successful_files) / float(project_result.total_files)
	result.stats["error_rate"] = 1.0 - success_rate
	
	if success_rate < 0.90:
		result.errors.append("Success rate %.2f%% is below 90%% threshold" % (success_rate * 100))
		return false
	
	print(" Analyzed %d files, %d successful (%.2f%%)" % [
		project_result.total_files, project_result.successful_files, success_rate * 100
	])
	return true

func test_error_rate() -> bool:
	var error_rate = result.stats["error_rate"]
	
	if error_rate >= 0.10:
		result.errors.append("Error rate %.2f%% exceeds 10%% threshold" % (error_rate * 100))
		return false
	
	print(" Error rate %.2f%% is below 10%% threshold" % (error_rate * 100))
	return true

func test_stability() -> bool:
	var test_cases = [
		"",  # Empty file
		"func test():\n\tif true:\n\t\tpass",
		"func test():\n\tif true:\n\t\tpass\n\t\tpass",  
		"if true:\n\tpass\nelse:\n\tpass", 
		"for i in range(10):\n\tpass", 
		"while true:\n\tpass", 
		"match x:\n\t1:\n\t\tpass",
		"func test():\n\treturn",  
		"class Test:\n\tfunc test():\n\t\tpass",  
		"signal test_signal", 
		"static func test():\n\tpass", 
		"if true and false:\n\tpass", 
		"if true or false:\n\tpass",
		"if not true:\n\tpass",
		"func test():\n\t# Comment\n\tpass", 
		"\"\"\"\nMulti-line string\n\"\"\"",  
		"func test(a: int, b: String) -> int:\n\treturn 0",
		"func test(): return 42",  # Single-line function
		"func test(): pass",  # Single-line function with pass
		"var x = 1",  # Single variable declaration
		"const PI = 3.14",  # Single constant
		"func _ready(): pass",  # Single-line _ready
		"func _process(_delta): pass",  # Single-line _process
		"extends Node",  # Only extends
		"class_name TestClass",  # Only class_name
		"@tool",  # Only tool annotation
		"@export var value = 0",  # Export variable
	]
	
	var crash_count = 0
	var handled_count = 0
	
	for test_code in test_cases:
		var handled = false
		var temp_path = "user://temp_test_%d.gd" % test_cases.find(test_code)
		
		if _write_file(temp_path, test_code):
			var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
			var tokenizer_script = load(tokenizer_path)
			assert(tokenizer_script != null, "Failed to load tokenizer script")
			var tokenizer = tokenizer_script.new()
			var tokens = tokenizer.tokenize_file(temp_path)
			var errors = tokenizer.get_errors()
			
			if tokens.size() > 0 or errors.size() > 0:
				handled = true
				handled_count += 1
			
			_remove_file(temp_path)
		
		if not handled:
			crash_count += 1
	
	result.stats["crash_count"] = crash_count
	
	if crash_count > 0:
		result.errors.append("%d test cases caused crashes or unhandled errors" % crash_count)
		return false
	
	print(" All %d test cases handled gracefully (no crashes)" % test_cases.size())
	return true

func test_indentation_ambiguity() -> bool:
	var test_cases = [
		{
			"code": "func test():\n\tif true:\n\t\tpass\n\telse:\n\t\tpass",
			"description": "If-else with consistent indentation"
		},
		{
			"code": "func test():\n\tif true:\n\t\tif false:\n\t\t\tpass",
			"description": "Nested if statements"
		},
		{
			"code": "class Test:\n\tfunc test():\n\t\tpass",
			"description": "Class with function"
		},
		{
			"code": "func test():\n\tfor i in range(10):\n\t\tif i > 5:\n\t\t\tpass",
			"description": "For loop with nested if"
		},
		{
			"code": "func test():\n\tmatch x:\n\t\t1:\n\t\t\tpass\n\t\t2:\n\t\t\tpass",
			"description": "Match with multiple cases"
		}
	]
	
	var issues = 0
	
	for test_case in test_cases:
		var temp_path = "user://temp_indent_%d.gd" % test_cases.find(test_case)
		
		if _write_file(temp_path, test_case["code"]):
			var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
			var tokenizer_script = load(tokenizer_path)
			assert(tokenizer_script != null, "Failed to load tokenizer script")
			var tokenizer = tokenizer_script.new()
			var tokens = tokenizer.tokenize_file(temp_path)
			
			var func_detector_script = load(SRC_ROOT + "/core/function_detector.gd")
			assert(func_detector_script != null, "Failed to load function_detector.gd")
			var func_detector = func_detector_script.new()
			var functions = func_detector.detect_functions(tokens)
			
			var class_detector_script = load(SRC_ROOT + "/core/class_detector.gd")
			assert(class_detector_script != null, "Failed to load class_detector.gd")
			var class_detector = class_detector_script.new()
			var classes = class_detector.detect_classes(tokens)
			
			if tokens.size() == 0:
				issues += 1
				result.warnings.append("Indentation test failed: %s" % test_case["description"])
			
			_remove_file(temp_path)
	
	result.stats["indentation_issues"] = issues
	
	if issues > 0:
		result.warnings.append("%d indentation test cases had issues" % issues)
		if issues > test_cases.size() / 2:
			result.errors.append("Too many indentation issues: %d/%d" % [issues, test_cases.size()])
			return false
	
	print(" Indentation handling: %d/%d test cases passed" % [test_cases.size() - issues, test_cases.size()])
	return true

func test_json_output(project_path: String) -> bool:
	var config_script = load(SRC_ROOT + "/config_manager.gd")
	assert(config_script != null, "Failed to load config_manager.gd")
	var config = config_script.new()
	var default_config = config.get_config()
	
	var batch_analyzer_script = load(SRC_ROOT + "/batch_analyzer.gd")
	assert(batch_analyzer_script != null, "Failed to load batch_analyzer.gd")
	var batch_analyzer = batch_analyzer_script.new()
	var project_result = batch_analyzer.analyze_project(project_path, default_config)
	
	if project_result.total_files == 0:
		result.errors.append("No files for JSON output test")
		return false
	
	var report_gen_script = load(SRC_ROOT + "/gd4/report_generator.gd")
	assert(report_gen_script != null, "Failed to load gd4/report_generator.gd")
	var report_gen = report_gen_script.new()
	var report = report_gen.generate_report(project_result, default_config)

	var required_keys = ["version", "timestamp", "project", "files", "worst_offenders"]
	for key in required_keys:
		if not report.has(key):
			result.errors.append("JSON report missing required key: %s" % key)
			return false

	if not report["project"].has("total_files"):
		result.errors.append("JSON report project section missing total_files")
		return false

	var json_string = JSON.stringify(report)
	
	if json_string.length() == 0:
		result.errors.append("JSON serialization failed")
		return false

	var temp_path = "user://temp_report.json"
	if not report_gen.write_report(report, temp_path):
		result.errors.append("Failed to write JSON report")
		return false

	if not _file_exists(temp_path):
		result.errors.append("JSON report file was not created")
		return false

	var content = _read_file(temp_path)
	if content.length() == 0:
		result.errors.append("Failed to read JSON report file")
		_remove_file(temp_path)
		return false
	
	var json = JSON.new()
	if json.parse(content) != OK:
		result.errors.append("Generated JSON report is invalid: %s" % json.get_error_message())
		_remove_file(temp_path)
		return false
	
	_remove_file(temp_path)
	
	print(" JSON report generation and validation passed")
	return true

func test_large_file_handling() -> bool:
	# Generate a large file with 1000+ lines
	var large_file_content = ""
	for i in range(1000):
		large_file_content += "func function_%d():\n" % i
		large_file_content += "\tif true:\n"
		large_file_content += "\t\treturn %d\n" % i
		large_file_content += "\n"
	
	var temp_path = "user://temp_large_file.gd"
	if not _write_file(temp_path, large_file_content):
		result.errors.append("Failed to create large test file")
		return false
	
	var start_time = _get_ticks_msec()
	var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
	var tokenizer_script = load(tokenizer_path)
	assert(tokenizer_script != null, "Failed to load tokenizer script")
	var tokenizer = tokenizer_script.new()
	var tokens = tokenizer.tokenize_file(temp_path)
	var errors = tokenizer.get_errors()
	var end_time = _get_ticks_msec()
	
	var parse_time = (end_time - start_time) / 1000.0
	result.stats["large_file_time"] = parse_time
	
	_remove_file(temp_path)
	
	if tokens.size() == 0 and errors.size() > 0:
		result.errors.append("Large file parsing failed with errors")
		return false
	
	if parse_time > 10.0:
		result.warnings.append("Large file parsing took %.3f seconds (threshold: 10s)" % parse_time)
	
	print(" Parsed %d-line file in %.3f seconds (%d tokens)" % [large_file_content.split("\n").size(), parse_time, tokens.size()])
	return true

func test_deeply_nested_code() -> bool:
	# Test with 15+ levels of nesting
	var nested_code = "func deeply_nested():\n"
	for i in range(15):
		var indent = ""
		for j in range(i + 1):
			indent += "\t"
		nested_code += indent + "if true:\n"
	var final_indent = ""
	for j in range(16):
		final_indent += "\t"
	nested_code += final_indent + "print(\"deep\")\n"
	
	var temp_path = "user://temp_deep_nesting.gd"
	if not _write_file(temp_path, nested_code):
		result.errors.append("Failed to create deep nesting test file")
		return false
	
	var start_time = _get_ticks_msec()
	var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
	var tokenizer_script = load(tokenizer_path)
	assert(tokenizer_script != null, "Failed to load tokenizer script")
	var tokenizer = tokenizer_script.new()
	var tokens = tokenizer.tokenize_file(temp_path)
	var errors = tokenizer.get_errors()
	var end_time = _get_ticks_msec()
	
	var parse_time = (end_time - start_time) / 1000.0
	result.stats["deep_nesting_time"] = parse_time
	
	# Test with the actual deep_nesting.gd fixture if available
	var fixture_path = "res://tests/fixtures/deep_nesting.gd"
	if _file_exists(fixture_path):
		var fixture_start = _get_ticks_msec()
		var fixture_tokens = tokenizer.tokenize_file(fixture_path)
		var fixture_errors = tokenizer.get_errors()
		var fixture_end = _get_ticks_msec()
		var fixture_time = (fixture_end - fixture_start) / 1000.0
		
		if fixture_tokens.size() == 0 and fixture_errors.size() > 0:
			result.warnings.append("Deep nesting fixture failed to parse")
		else:
			print(" Parsed deep_nesting.gd fixture in %.3f seconds" % fixture_time)
	
	_remove_file(temp_path)
	
	if tokens.size() == 0 and errors.size() > 0:
		result.errors.append("Deep nesting parsing failed")
		return false
	
	if parse_time > 5.0:
		result.warnings.append("Deep nesting parsing took %.3f seconds (threshold: 5s)" % parse_time)
	
	print(" Parsed 15-level nested code in %.3f seconds (%d tokens)" % [parse_time, tokens.size()])
	return true

func test_edge_cases() -> bool:
	var edge_cases = [
		{
			"code": "",
			"description": "Empty file"
		},
		{
			"code": "func test(): return 42",
			"description": "Single-line function"
		},
		{
			"code": "func test(): pass",
			"description": "Single-line function with pass"
		},
		{
			"code": "var x = 1",
			"description": "Single variable declaration"
		},
		{
			"code": "const PI = 3.14",
			"description": "Single constant"
		},
		{
			"code": "extends Node",
			"description": "Only extends statement"
		},
		{
			"code": "class_name TestClass",
			"description": "Only class_name"
		},
		{
			"code": "@tool",
			"description": "Only tool annotation"
		},
		{
			"code": "@export var value = 0",
			"description": "Export variable"
		},
		{
			"code": "func test():\n\tpass",
			"description": "Minimal function"
		},
		{
			"code": "class Test:\n\tpass",
			"description": "Minimal class"
		},
		{
			"code": "signal test_signal",
			"description": "Only signal"
		},
		{
			"code": "enum {A, B, C}",
			"description": "Only enum"
		},
		{
			"code": "func test():\n\t# Only comment\n\tpass",
			"description": "Function with only comment"
		}
	]
	
	var passed = 0
	var failed = 0
	
	for edge_case in edge_cases:
		var temp_path = "user://temp_edge_%d.gd" % edge_cases.find(edge_case)
		
		if _write_file(temp_path, edge_case["code"]):
			var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
			var tokenizer_script = load(tokenizer_path)
			assert(tokenizer_script != null, "Failed to load tokenizer script")
			var tokenizer = tokenizer_script.new()
			var tokens = tokenizer.tokenize_file(temp_path)
			var errors = tokenizer.get_errors()
			
			# Edge cases should either produce tokens or handle errors gracefully
			if tokens.size() > 0 or errors.size() > 0:
				passed += 1
			else:
				failed += 1
				result.warnings.append("Edge case failed: %s" % edge_case["description"])
			
			_remove_file(temp_path)
	
	result.stats["edge_case_count"] = passed
	
	if failed > edge_cases.size() / 2:
		result.errors.append("Too many edge case failures: %d/%d" % [failed, edge_cases.size()])
		return false
	
	print(" Edge cases: %d/%d passed" % [passed, edge_cases.size()])
	return true

func test_performance_benchmarks() -> bool:
	# Benchmark parsing performance with various file sizes
	var benchmarks = [
		{"lines": 10, "name": "Small file (10 lines)"},
		{"lines": 100, "name": "Medium file (100 lines)"},
		{"lines": 500, "name": "Large file (500 lines)"},
		{"lines": 1000, "name": "Very large file (1000 lines)"}
	]
	
	var total_time = 0.0
	var test_count = 0
	
	for benchmark in benchmarks:
		var content = ""
		for i in range(benchmark["lines"]):
			content += "func function_%d():\n" % i
			content += "\tif true:\n"
			content += "\t\treturn %d\n" % i
			content += "\n"
		
		var temp_path = "user://temp_bench_%d.gd" % benchmarks.find(benchmark)
		if not _write_file(temp_path, content):
			continue
		
		var start_time = _get_ticks_msec()
		var tokenizer_path = SRC_ROOT + "/tokenizer.gd"
		var tokenizer_script = load(tokenizer_path)
		assert(tokenizer_script != null, "Failed to load tokenizer script")
		var tokenizer = tokenizer_script.new()
		var tokens = tokenizer.tokenize_file(temp_path)
		var end_time = _get_ticks_msec()
		
		var parse_time = (end_time - start_time) / 1000.0
		total_time += parse_time
		test_count += 1
		
		print(" %s: %.3f seconds (%d tokens)" % [benchmark["name"], parse_time, tokens.size()])
		
		_remove_file(temp_path)
	
	if test_count > 0:
		result.stats["performance_avg_time"] = total_time / float(test_count)
		print(" Average parse time: %.3f seconds" % result.stats["performance_avg_time"])
	
	return true

