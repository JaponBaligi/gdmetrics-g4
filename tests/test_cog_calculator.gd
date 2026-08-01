# Unit tests for C-COG Calculator
# Run with: godot --headless --script tests/test_cog_calculator.gd

extends SceneTree

var cog_calculator = null
var control_flow_detector = null
var tokenizer = null
var function_detector = null
var tests_passed = 0
var tests_failed = 0

func _init():
	cog_calculator = load("res://addons/gdscript_complexity/src/core/cog_complexity_calculator.gd").new()
	control_flow_detector = load("res://addons/gdscript_complexity/src/core/control_flow_detector.gd").new()
	function_detector = load("res://addons/gdscript_complexity/src/core/function_detector.gd").new()
	tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("C-COG Calculator Unit Tests")
	print("========================================\n")
	
	test_base_complexity()
	test_nesting_penalties()
	test_match_case_handling()
	test_per_function_cog()
	
	print("\n========================================")
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("========================================")

func assert_true(condition: bool, message: String):
	if condition:
		tests_passed += 1
		print("PASS: %s" % message)
	else:
		tests_failed += 1
		print("FAIL: %s" % message)

func analyze_file(file_path: String) -> Dictionary:
	var tokens = tokenizer.tokenize_file(file_path)
	var functions = function_detector.detect_functions(tokens)
	var version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	var control_flow_nodes = control_flow_detector.detect_control_flow(tokens, version_adapter)
	var cog_result = cog_calculator.calculate_cog(control_flow_nodes, functions)
	return {
		"cog": cog_result.total_cog,
		"breakdown": cog_result.breakdown,
		"functions": functions,
		"control_flow_nodes": control_flow_nodes
	}

func test_base_complexity():
	print("Testing base complexity...")
	var result = analyze_file("res://tests/fixtures/simple_function.gd")
	assert_true(result.cog == 0, "Base complexity is 0 (no control flow)")

func test_nesting_penalties():
	print("Testing nesting penalties...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	# if (depth 1) = 2, for (depth 2) = 3, if (depth 3) = 4
	# Total: 2 + 3 + 4 = 9
	assert_true(result.cog == 9, "Nesting penalties applied correctly (C-COG: 9)")

func test_match_case_handling():
	print("Testing match/case handling...")
	var result = analyze_file("res://tests/fixtures/match_statement.gd")
	# match (depth 1) = 2, 3 arms = 3, returns inside control flow = 3
	# Total: 8
	assert_true(result.cog == 8, "Match arms handled correctly (C-COG: 8)")

func test_per_function_cog():
	print("Testing per-function C-COG...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	assert_true(result.functions.size() > 0, "Functions detected")
	# Per-function C-COG would require analyzing each function separately
	# This is a placeholder for more detailed testing
