# entry point for complexity analysis
# Run with: godot --script cli/analyze.gd -- file.gd

extends SceneTree

func _initialize():
	var args = OS.get_cmdline_args()
	var file_path = null

	var dash_index = args.find("--")
	if dash_index >= 0 and dash_index + 1 < args.size():
		file_path = args[dash_index + 1]
	
	if not file_path:
		print("Usage: godot --script cli/analyze.gd -- <file.gd>")
		call_deferred("quit", 1)
		return

	var result = analyze_file(file_path)

	print(JSON.stringify(result))

	if result.has("error"):
		call_deferred("quit", 1)
	else:
		call_deferred("quit", 0)

func analyze_file(file_path: String) -> Dictionary:

	var result = {
		"file": file_path,
		"success": false,
		"cc": 0,
		"errors": []
	}

	var version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	
	var tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	var tokens = tokenizer.tokenize_file(file_path)
	var tokenizer_errors = tokenizer.get_errors()
	
	if tokenizer_errors.size() > 0:
		result["errors"] = tokenizer_errors
		result["error"] = "Tokenization failed"
		return result
	
	if tokens.size() == 0:
		result["error"] = "No tokens found in file"
		return result

	var detector = load("res://addons/gdscript_complexity/src/control_flow_detector.gd").new()
	var control_flow_nodes = detector.detect_control_flow(tokens, version_adapter)
	var detector_errors = detector.get_errors()
	
	if detector_errors.size() > 0:
		result["errors"] = detector_errors

	var cc_calc = load("res://addons/gdscript_complexity/src/cc_calculator.gd").new()
	var cc = cc_calc.calculate_cc(control_flow_nodes)
	var breakdown = cc_calc.get_breakdown()
	
	result["success"] = true
	result["cc"] = cc
	result["breakdown"] = breakdown
	result["control_flow_count"] = control_flow_nodes.size()
	
	return result

