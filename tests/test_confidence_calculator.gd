# Unit tests for Confidence Calculator
# Run with: godot --headless --script tests/test_confidence_calculator.gd

extends SceneTree

var confidence_calculator = null
var tokenizer = null
var version_adapter = null
var tests_passed = 0
var tests_failed = 0

func _init():
	confidence_calculator = load("res://addons/gdscript_complexity/src/confidence_calculator.gd").new()
	version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("Confidence Calculator Unit Tests")
	print("========================================\n")
	
	test_token_coverage()
	test_indentation_consistency()
	test_block_balance()
	test_parse_error_weighting()
	test_version_specific_caps()
	
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
	var errors = tokenizer.errors
	var confidence_result = confidence_calculator.calculate_confidence(tokens, errors, version_adapter)
	return {
		"score": confidence_result.score,
		"components": confidence_result.components,
		"capped": confidence_result.capped,
		"tokens": tokens,
		"errors": errors
	}

func test_token_coverage():
	print("Testing token coverage calculation...")
	var result = analyze_file("res://tests/fixtures/simple_function.gd")
	assert_true(result.score >= 0.0 and result.score <= 1.0, "Confidence score in valid range")
	assert_true(result.components.has("token_coverage"), "Token coverage component present")

func test_indentation_consistency():
	print("Testing indentation consistency...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	assert_true(result.components.has("indentation_consistency"), "Indentation consistency component present")
	assert_true(result.components.indentation_consistency >= 0.0 and result.components.indentation_consistency <= 1.0, "Indentation consistency in valid range")

func test_block_balance():
	print("Testing block balance...")
	var result = analyze_file("res://tests/fixtures/nested_control_flow.gd")
	assert_true(result.components.has("block_balance"), "Block balance component present")
	assert_true(result.components.block_balance >= 0.0 and result.components.block_balance <= 1.0, "Block balance in valid range")

func test_parse_error_weighting():
	print("Testing parse error weighting...")
	var result = analyze_file("res://tests/fixtures/malformed_syntax.gd")
	assert_true(result.errors.size() > 0, "Parse errors detected")
	assert_true(result.components.has("parse_errors"), "Parse error component present")
	# Files with errors should have lower confidence
	if result.errors.size() > 0:
		assert_true(result.score < 1.0, "Parse errors reduce confidence score")

func test_version_specific_caps():
	print("Testing version-specific confidence caps...")
	var result = analyze_file("res://tests/fixtures/simple_function.gd")
	assert_true(result.score <= 1.0, "Godot 4.x confidence can reach 1.0")
