extends Object
# class_name CogComplexityCalculator

# Cognitive Complexity calculator
# Formula: C-COG = sum of (1 + depth) for each control flow structure
# Special rule: case statements count as +1 regardless of nesting depth

class CogComplexityResult:
	var total_cog: int = 0
	var breakdown: Dictionary = {}
	var per_function: Dictionary = {}
	var per_function_breakdown: Dictionary = {}
	
	func _init():
		breakdown = _empty_breakdown()

	func _empty_breakdown() -> Dictionary:
		return {
			"if": 0,
			"elif": 0,
			"for": 0,
			"while": 0,
			"match": 0,
			"case": 0,
			"ternary": 0,
			"and": 0,
			"or": 0,
			"not": 0,
			"return": 0,
			"break": 0,
			"continue": 0,
			"lambda": 0
		}

var result: CogComplexityResult
var in_match_block: bool = false
var match_start_line: int = -1

func calculate_cog(control_flow_nodes: Array, functions: Array = []) -> CogComplexityResult:
	result = CogComplexityResult.new()
	in_match_block = false
	match_start_line = -1
	
	if control_flow_nodes.size() == 0:
		return result
	
	var i = 0
	while i < control_flow_nodes.size():
		var node = control_flow_nodes[i]
		_apply_node(node, result, true)
		i += 1
	
	if functions.size() > 0:
		_calculate_per_function(control_flow_nodes, functions)
	
	return result

func _calculate_per_function(control_flow_nodes: Array, functions: Array):
	for func_info in functions:
		var func_nodes: Array = []
		for node in control_flow_nodes:
			if node.line >= func_info.start_line and node.line <= func_info.end_line:
				func_nodes.append(node)
		
		var func_result = CogComplexityResult.new()
		in_match_block = false
		match_start_line = -1
		
		for node in func_nodes:
			_apply_node(node, func_result, true)
		
		result.per_function[func_info.name] = func_result.total_cog
		result.per_function_breakdown[func_info.name] = func_result.breakdown.duplicate()

func _apply_node(node, target_result: CogComplexityResult, allow_match_tracking: bool):
	if node.type == "lambda":
		# Flat +1 for each lambda (including nested). Body nodes do not leak
		# into the enclosing scope (see lambda_depth check below).
		target_result.total_cog += 1
		target_result.breakdown["lambda"] += 1
		return

	# Lambda body: score only via the lambda marker above, not parent totals.
	if node.lambda_depth > 0:
		return
	
	if node.type == "match":
		if allow_match_tracking:
			in_match_block = true
			match_start_line = node.line
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["match"] += contribution
		return
	
	if node.type == "case":
		if allow_match_tracking and not in_match_block:
			return
		var patterns = 1
		var has_guard = false
		patterns = max(1, int(node.case_pattern_count))
		has_guard = node.case_has_guard
		var contribution = 1 + max(0, patterns - 1) + (1 if has_guard else 0)
		target_result.total_cog += contribution
		target_result.breakdown["case"] += contribution
		return
	
	if node.type == "return" or node.type == "break" or node.type == "continue":
		if node.in_control_flow:
			target_result.total_cog += 1
			target_result.breakdown[node.type] += 1
		return
	
	if node.type == "if":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["if"] += contribution
	elif node.type == "ternary":
		# Ternary is a decision without nesting bump beyond current depth
		var contribution_t = 1 + node.depth
		target_result.total_cog += contribution_t
		target_result.breakdown["ternary"] += contribution_t
	elif node.type == "elif":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["elif"] += contribution
	elif node.type == "for":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["for"] += contribution
	elif node.type == "while":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["while"] += contribution
	elif node.type == "and":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["and"] += contribution
	elif node.type == "or":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["or"] += contribution
	elif node.type == "not":
		var contribution = 1 + node.depth
		target_result.total_cog += contribution
		target_result.breakdown["not"] += contribution

func get_total_cog() -> int:
	if result == null:
		return 0
	return result.total_cog

func get_breakdown() -> Dictionary:
	if result == null:
		return {}
	return result.breakdown.duplicate()

func get_per_function() -> Dictionary:
	if result == null:
		return {}
	return result.per_function.duplicate()

