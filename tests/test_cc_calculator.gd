# Unit tests for CC Calculator
# Run with: godot --headless --script tests/test_cc_calculator.gd

extends SceneTree

var cc_calculator = null
var control_flow_detector = null
var tokenizer = null
var function_detector = null
var tests_passed = 0
var tests_failed = 0

func _init():
	cc_calculator = load("res://addons/gdscript_complexity/src/core/cc_calculator.gd").new()
	control_flow_detector = load("res://addons/gdscript_complexity/src/core/control_flow_detector.gd").new()
	function_detector = load("res://addons/gdscript_complexity/src/core/function_detector.gd").new()
	tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("CC Calculator Unit Tests")
	print("========================================\n")
	
	test_base_complexity()
	test_if_statement()
	test_elif_statement()
	test_for_loop()
	test_while_loop()
	test_match_case()
	test_logical_operators()
	test_nested_control_flow()
	test_per_function_cc()
	
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
	var cc = cc_calculator.calculate_cc(control_flow_nodes)
	return {
		"cc": cc,
		"functions": functions,
		"control_flow_nodes": control_flow_nodes
	}

func test_base_complexity():
	print("Testing base complexity...")
	var result = analyze_file("res://tests/fixtures/simple_function.gd")
	assert_true(result.cc == 1, "Base complexity is 1")

func test_if_statement():
	print("Testing if statement...")
	var result = analyze_file("res://tests/fixtures/if_statement.gd")
	assert_true(result.cc == 2, "if statement adds +1 CC (total: 2)")

func test_elif_statement():
	print("Testing elif statement...")
	var result = analyze_file("res://tests/fixtures/if_elif_else.gd")
	assert_true(result.cc == 3, "if/elif adds +2 CC (total: 3)")

func test_for_loop():
	print("Testing for loop...")
	var result = analyze_file("res://tests/fixtures/for_loop.gd")
	assert_true(result.cc == 2, "for loop adds +1 CC (total: 2)")

func test_while_loop():
	print("Testing while loop...")
	var result = analyze_file("res://tests/fixtures/while_loop.gd")
	assert_true(result.cc == 2, "while loop adds +1 CC (total: 2)")

func test_match_case():
	print("Testing match/case...")
	var result = analyze_file("res://tests/fixtures/match_statement.gd")
	assert_true(result.cc == 5, "match + 3 arms add +4 CC (total: 5)")

func test_logical_operators():
	print("Testing logical operators...")
	var result = analyze_file("res://tests/fixtures/logical_operators.gd")
	assert_true(result.cc == 5, "if + and + if + or adds +4 CC (total: 5)")

func test_nested_control_flow():
	print("Testing nested control flow...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	assert_true(result.cc == 4, "Nested if/for adds +3 CC (total: 4)")

func test_per_function_cc():
	print("Testing per-function CC...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	assert_true(result.functions.size() > 0, "Functions detected")
	# Per-function CC would require analyzing each function separately
	# This is a placeholder for more detailed testing
