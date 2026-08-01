# Confidence validation and tuning tool
# Run with: godot --headless --script tests/validate_confidence.gd -- [--apply] [--step 0.1] [--min-r2 0.7] [--metrics-out path]

extends SceneTree

var expected_values = {
	"simple_function.gd": {"cc": 1, "cog": 0},
	"if_statement.gd": {"cc": 2, "cog": 3},
	"if_elif_else.gd": {"cc": 3, "cog": 6},
	"for_loop.gd": {"cc": 2, "cog": 2},
	"while_loop.gd": {"cc": 2, "cog": 2},
	"nested_control_flow.gd": {"cc": 4, "cog": 9},
	"match_statement.gd": {"cc": 5, "cog": 8},
	"logical_operators.gd": {"cc": 5, "cog": 10},
	"class_with_inheritance.gd": {"cc": 2, "cog": 2},
	"empty_file.gd": {"cc": 1, "cog": 0},
	"with_yield.gd": {"cc": 2, "cog": 2},
	"no_match.gd": {"cc": 3, "cog": 6},
	"annotations.gd": {"cc": 2, "cog": 2},
	"malformed_syntax.gd": {"cc": 0, "cog": 0},
	"unterminated_string.gd": {"cc": 0, "cog": 0},
	"unbalanced_brackets.gd": {"cc": 0, "cog": 0}
}

func _init():
	_run()

func _initialize():
	_run()

func _run():
	var args = OS.get_cmdline_args()
	var apply_weights = false
	var step = 0.1
	var enforce_min_r2 = false
	var min_r2 = 0.0
	var metrics_output = ""
	
	var dash_index = args.find("--")
	if dash_index >= 0:
		for i in range(dash_index + 1, args.size()):
			if args[i] == "--apply":
				apply_weights = true
			elif args[i] == "--step" and i + 1 < args.size():
				step = float(args[i + 1])
			elif args[i] == "--min-r2" and i + 1 < args.size():
				enforce_min_r2 = true
				min_r2 = float(args[i + 1])
			elif args[i] == "--metrics-out" and i + 1 < args.size():
				metrics_output = args[i + 1]
	
	var version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	var config_manager = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	var config = config_manager.get_config()
	
	var scores = _collect_scores(config, version_adapter)
	if scores.size() == 0:
		print("No scores collected, aborting.")
		call_deferred("quit", 1)
		return
	
	var current_r2 = _compute_r2(scores)
	print("Current r^2: %.4f" % current_r2)
	
	var tune_result = _tune_weights(scores, step)
	print("Best r^2: %.4f" % tune_result.r2)
	print("Best weights: %s" % str(tune_result.weights))

	if metrics_output != "":
		_write_metrics(metrics_output, current_r2, tune_result.r2, tune_result.weights, step)
	
	var exit_code = 0
	if enforce_min_r2 and current_r2 < min_r2:
		print("ERROR: Current r^2 %.4f is below required minimum %.4f" % [current_r2, min_r2])
		exit_code = 1
	
	if tune_result.r2 > current_r2 and apply_weights:
		if _apply_weights_to_config(tune_result.weights):
			print("Applied weights to complexity_config.json")
		else:
			print("Failed to write complexity_config.json")
	
	call_deferred("quit", exit_code)

func _collect_scores(config, version_adapter) -> Array:
	var scores = []
	var fixtures_path = "res://tests/fixtures"
	var discovery = load("res://addons/gdscript_complexity/src/gd4/file_discovery.gd").new()
	var files = discovery.find_files(fixtures_path, ["res://**/*.gd"], [])
	
	var detector = load("res://addons/gdscript_complexity/src/control_flow_detector.gd").new()
	var func_detector = load("res://addons/gdscript_complexity/src/function_detector.gd").new()
	var cc_calc = load("res://addons/gdscript_complexity/src/cc_calculator.gd").new()
	var cog_calc = load("res://addons/gdscript_complexity/src/cog_complexity_calculator.gd").new()
	var confidence_calc = load("res://addons/gdscript_complexity/src/confidence_calculator.gd").new()
	
	for file_path in files:
		var filename = file_path.get_file()
		if not expected_values.has(filename):
			continue
		
		var tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
		var tokens = tokenizer.tokenize_file(file_path)
		var errors = tokenizer.get_errors()
		var parse_quality = _compute_parse_quality(errors, tokens.size())
		
		var control_flow_nodes = detector.detect_control_flow(tokens, version_adapter)
		var functions = func_detector.detect_functions(tokens)
		
		var actual_cc = cc_calc.calculate_cc(control_flow_nodes)
		var actual_cog = cog_calc.calculate_cog(control_flow_nodes, functions).total_cog
		
		var confidence_result = confidence_calc.calculate_confidence(tokens, errors, version_adapter, config.parser_config.get("confidence_weights", {}))
		var confidence = confidence_result.score
		var accuracy = _compute_accuracy(expected_values[filename], actual_cc, actual_cog, parse_quality)
		
		scores.append({
			"confidence": confidence,
			"accuracy": accuracy,
			"components": confidence_result.components
		})
	
	return scores

func _compute_accuracy(expected: Dictionary, actual_cc: int, actual_cog: int, parse_quality: float) -> float:
	# Continuous accuracy based on distance from expected values,
	# combined with parse quality (weighted toward parse quality).
	var expected_total = max(1, int(expected["cc"]) + int(expected["cog"]))
	var error = abs(actual_cc - int(expected["cc"])) + abs(actual_cog - int(expected["cog"]))
	var metric_accuracy = clamp(1.0 - (float(error) / float(expected_total)), 0.0, 1.0)
	return (metric_accuracy * 0.3) + (parse_quality * 0.7)

func _compute_parse_quality(errors: Array, token_count: int) -> float:
	if token_count == 0:
		return 0.0
	
	var error_count = errors.size()
	var error_ratio = float(error_count) / float(token_count)
	
	var score = 1.0 - min(1.0, error_ratio * 10.0)
	return max(0.0, score)

func _compute_r2(scores: Array) -> float:
	if scores.size() == 0:
		return 0.0
	var mean = 0.0
	for item in scores:
		mean += item.accuracy
	mean = mean / float(scores.size())
	
	var ss_tot = 0.0
	var ss_res = 0.0
	for item in scores:
		ss_tot += pow(item.accuracy - mean, 2)
		ss_res += pow(item.accuracy - item.confidence, 2)
	
	if ss_tot == 0.0:
		return 0.0
	return 1.0 - (ss_res / ss_tot)

func _tune_weights(scores: Array, step: float) -> Dictionary:
	var best_r2 = -1.0
	var best = {
		"token_coverage": 0.4,
		"indentation_consistency": 0.2,
		"block_balance": 0.2,
		"parse_errors": 0.2
	}
	
	var weights = _generate_weight_grid(step)
	for candidate in weights:
		var r2 = _compute_r2_with_weights(scores, candidate)
		if r2 > best_r2:
			best_r2 = r2
			best = candidate
	
	return {"r2": best_r2, "weights": best}

func _compute_r2_with_weights(scores: Array, weights: Dictionary) -> float:
	if scores.size() == 0:
		return 0.0
	var mean = 0.0
	for item in scores:
		mean += item.accuracy
	mean = mean / float(scores.size())
	
	var ss_tot = 0.0
	var ss_res = 0.0
	for item in scores:
		var predicted = _predict_confidence(item.components, weights)
		ss_tot += pow(item.accuracy - mean, 2)
		ss_res += pow(item.accuracy - predicted, 2)
	
	if ss_tot == 0.0:
		return 0.0
	return 1.0 - (ss_res / ss_tot)

func _predict_confidence(components: Dictionary, weights: Dictionary) -> float:
	var predicted = 0.0
	for key in weights.keys():
		if components.has(key):
			predicted += components[key] * weights[key]
	return clamp(predicted, 0.0, 1.0)

func _generate_weight_grid(step: float) -> Array:
	var grid = []
	var keys = ["token_coverage", "indentation_consistency", "block_balance", "parse_errors"]
	var max_steps = int(1.0 / step)
	
	for a in range(max_steps + 1):
		for b in range(max_steps + 1):
			for c in range(max_steps + 1):
				for d in range(max_steps + 1):
					var total = a + b + c + d
					if total == 0:
						continue
					var weights = {
						keys[0]: float(a) * step,
						keys[1]: float(b) * step,
						keys[2]: float(c) * step,
						keys[3]: float(d) * step
					}
					var sum = weights[keys[0]] + weights[keys[1]] + weights[keys[2]] + weights[keys[3]]
					if abs(sum - 1.0) <= 0.0001:
						grid.append(weights)
	
	return grid

func _apply_weights_to_config(weights: Dictionary) -> bool:
	var file_path = "res://complexity_config.json"
	var file_helper = load("res://tests/file_helper_4.gd").new()
	var content = file_helper.read_file(file_path)
	if content == "":
		return false
	
	var data = file_helper.parse_json(content)
	if data.size() == 0:
		return false
	
	if not data.has("parser"):
		data["parser"] = {}
	data["parser"]["confidence_weights"] = weights
	
	var json_text = file_helper.stringify_json(data)
	
	return file_helper.write_file(file_path, json_text)

func _write_metrics(output_path: String, current_r2: float, best_r2: float, best_weights: Dictionary, step: float) -> void:
	var file_helper = load("res://tests/file_helper_4.gd").new()
	var payload = {
		"current_r2": current_r2,
		"best_r2": best_r2,
		"best_weights": best_weights,
		"step": step
	}
	var json_text = file_helper.stringify_json(payload)
	file_helper.write_file(output_path, json_text)

