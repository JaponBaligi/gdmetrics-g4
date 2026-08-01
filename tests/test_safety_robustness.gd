# Safety and robustness tests
# Run with: godot --headless --script tests/test_safety_robustness.gd

extends SceneTree

var tokenizer = null
var control_flow_detector = null
var cog_calculator = null
var tests_passed = 0
var tests_failed = 0
var file_helper = null

func _init():
	tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	file_helper = load("res://tests/file_helper_4.gd").new()
	control_flow_detector = load("res://addons/gdscript_complexity/src/control_flow_detector.gd").new()
	cog_calculator = load("res://addons/gdscript_complexity/src/cog_complexity_calculator.gd").new()
	
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("Safety and Robustness Tests")
	print("========================================\n")
	
	test_malformed_fixtures()
	test_large_file()
	test_deep_nesting()
	test_edge_cases()
	
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

func test_malformed_fixtures():
	print("Testing malformed fixtures...")
	var malformed_files = [
		"res://tests/fixtures/malformed_syntax.gd",
		"res://tests/fixtures/unbalanced_brackets.gd",
		"res://tests/fixtures/unterminated_string.gd"
	]
	for file_path in malformed_files:
		var tokens = tokenizer.tokenize_file(file_path)
		assert_true(tokens != null, "Tokenizer returns for %s" % file_path.get_file())
		assert_true(tokenizer.get_errors().size() > 0, "Errors reported for %s" % file_path.get_file())

func test_large_file():
	print("Testing very large file (>10k lines)...")
	var file_path = "user://safety_large.gd"
	var content = _build_large_file(10050)
	_write_file(file_path, content)
	var tokens = tokenizer.tokenize_file(file_path)
	assert_true(tokens.size() > 0, "Large file tokenized")
	assert_true(tokenizer.get_errors().size() == 0, "Large file has no tokenizer errors")
	_cleanup_file(file_path)

func test_deep_nesting():
	print("Testing deep nesting...")
	var file_path = "user://safety_deep_nesting.gd"
	var content = _build_deep_nesting(60)
	_write_file(file_path, content)
	var tokens = tokenizer.tokenize_file(file_path)
	assert_true(tokens.size() > 0, "Deep nesting tokenized")
	assert_true(tokenizer.get_errors().size() == 0, "Deep nesting has no tokenizer errors")
	var nodes = control_flow_detector.detect_control_flow(tokens, null)
	var cog_result = cog_calculator.calculate_cog(nodes, [])
	assert_true(cog_result.total_cog > 0, "Deep nesting produces C-COG")
	_cleanup_file(file_path)

func test_edge_cases():
	print("Testing edge cases...")
	# Empty file fixture
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/empty_file.gd")
	assert_true(tokens != null, "Empty file handled")
	
	# Single-line function
	var file_path = "user://safety_single_line.gd"
	var content = "func single_line(): return 1\n"
	_write_file(file_path, content)
	tokens = tokenizer.tokenize_file(file_path)
	assert_true(tokens.size() > 0, "Single-line function tokenized")
	assert_true(tokenizer.get_errors().size() == 0, "Single-line function has no tokenizer errors")
	_cleanup_file(file_path)

func _build_large_file(line_count: int) -> String:
	var lines: Array = []
	lines.append("func huge():")
	for i in range(line_count):
		lines.append("\tvar v_%d = %d" % [i, i])
	return "\n".join(lines) + "\n"

func _build_deep_nesting(depth: int) -> String:
	var lines: Array = []
	lines.append("func deep():")
	for i in range(depth):
		lines.append("\t".repeat(i + 1) + "if true:")
	lines.append("\t".repeat(depth + 1) + "return 0")
	return "\n".join(lines) + "\n"

func _write_file(path: String, content: String):
	file_helper.write_file(path, content)

func _cleanup_file(path: String):
	var name = path.replace("user://", "")
	file_helper.remove_file(name)
