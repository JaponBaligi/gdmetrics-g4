# Run with: godot --script test_tokenizer.gd -- test_file.gd

extends RefCounted

func _init():
	var args = OS.get_cmdline_args()
	var file_path = null
	
	# Find file argument (after --)
	var dash_index = args.find("--")
	if dash_index >= 0 and dash_index + 1 < args.size():
		file_path = args[dash_index + 1]
	
	if not file_path:
		print("Usage: godot --script test_tokenizer.gd -- <file.gd>")
		return
	
	var tokenizer = preload("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	var tokens = tokenizer.tokenize_file(file_path)
	var errors = tokenizer.get_errors()
	
	print("=== Tokenizer Test ===")
	print("File: %s" % file_path)
	print("Tokens found: %d" % tokens.size())
	print("Errors: %d" % errors.size())
	print("")
	
	if errors.size() > 0:
		print("Errors:")
		for error in errors:
			print("  %s" % error)
		print("")
	
	print("=== Control Flow Detection ===")
	var detector = preload("res://addons/gdscript_complexity/src/core/control_flow_detector.gd").new()
	var nodes = detector.detect_control_flow(tokens)
	print("Control flow nodes found: %d" % nodes.size())
	print("")
	print("Breakdown:")
	print("  if: %d" % detector.count_by_type("if"))
	print("  elif: %d" % detector.count_by_type("elif"))
	print("  for: %d" % detector.count_by_type("for"))
	print("  while: %d" % detector.count_by_type("while"))
	print("  match: %d" % detector.count_by_type("match"))
	print("  case: %d" % detector.count_by_type("case"))
	print("  and: %d" % detector.count_by_type("and"))
	print("  or: %d" % detector.count_by_type("or"))
	print("  not: %d" % detector.count_by_type("not"))
	print("")
	print("Nodes with depth:")
	for node in nodes:
		print("  %s" % node)
	print("")
	
	print("=== Cyclomatic Complexity ===")
	var cc_calc = preload("res://addons/gdscript_complexity/src/core/cc_calculator.gd").new()
	var cc = cc_calc.calculate_cc(nodes)
	var breakdown = cc_calc.get_breakdown()
	print("CC = %d" % cc)
	print("Breakdown:")
	print("  Base: %d" % breakdown["base"])
	print("  if: %d (+%d)" % [breakdown["if"], breakdown["if"]])
	print("  elif: %d (+%d)" % [breakdown["elif"], breakdown["elif"]])
	print("  for: %d (+%d)" % [breakdown["for"], breakdown["for"]])
	print("  while: %d (+%d)" % [breakdown["while"], breakdown["while"]])
	print("  match: %d (+%d)" % [breakdown.get("match", 0), breakdown.get("match", 0)])
	print("  case: %d (+%d)" % [breakdown.get("case", 0), breakdown.get("case", 0)])
	print("  and: %d (+%d)" % [breakdown["and"], breakdown["and"]])
	print("  or: %d (+%d)" % [breakdown["or"], breakdown["or"]])
	print("  not: %d (+%d)" % [breakdown["not"], breakdown["not"]])
	
	print("")
	print("=== Function Detection ===")
	var func_detector = preload("res://addons/gdscript_complexity/src/core/function_detector.gd").new()
	var functions = func_detector.detect_functions(tokens)
	print("Functions found: %d" % functions.size())
	for func_info in functions:
		print("  %s %s() [%d-%d] params=%d return=%s" % [
			func_info.type, func_info.name, func_info.start_line, func_info.end_line,
			func_info.parameters.size(), func_info.return_type if func_info.return_type != "" else "void"
		])
	
	print("")
	print("=== Cognitive Complexity (C-COG) ===")
	var cog_calc = preload("res://addons/gdscript_complexity/src/core/cog_complexity_calculator.gd").new()
	var cog_result = cog_calc.calculate_cog(nodes, functions)
	print("Total C-COG = %d" % cog_result.total_cog)
	print("Breakdown:")
	print("  if: %d" % cog_result.breakdown["if"])
	print("  elif: %d" % cog_result.breakdown["elif"])
	print("  for: %d" % cog_result.breakdown["for"])
	print("  while: %d" % cog_result.breakdown["while"])
	print("  match: %d" % cog_result.breakdown["match"])
	print("  case: %d" % cog_result.breakdown["case"])
	print("  and: %d" % cog_result.breakdown["and"])
	print("  or: %d" % cog_result.breakdown["or"])
	print("  not: %d" % cog_result.breakdown["not"])
	if cog_result.per_function.size() > 0:
		print("Per-function C-COG:")
		for func_name in cog_result.per_function:
			print("  %s(): %d" % [func_name, cog_result.per_function[func_name]])
	
	print("")
	print("=== Class Detection ===")
	var class_detector = preload("res://addons/gdscript_complexity/src/core/class_detector.gd").new()
	var classes = class_detector.detect_classes(tokens)
	print("Classes found: %d" % classes.size())
	for class_info in classes:
		print("  %s" % class_info)
	
	print("")
	print("=== Confidence Score ===")
	var confidence_calc = preload("res://addons/gdscript_complexity/src/core/confidence_calculator.gd").new()
	var confidence_result = confidence_calc.calculate_confidence(tokens, errors, "4.0")
	print("Confidence Score: %.2f" % confidence_result.score)
	print("Components:")
	print("  Token Coverage: %.2f" % confidence_result.components["token_coverage"])
	print("  Indentation Consistency: %.2f" % confidence_result.components["indentation_consistency"])
	print("  Block Balance: %.2f" % confidence_result.components["block_balance"])
	print("  Parse Errors: %.2f" % confidence_result.components["parse_errors"])
	if confidence_result.capped:
		print("  (Capped: %s)" % confidence_result.cap_reason)
	
	print("")
	print("=== End Test ===")
