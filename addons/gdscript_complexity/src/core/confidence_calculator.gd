extends Object
# class_name ConfidenceCalculator

# confidence score calculator
# calculates parse confidence based on token coverage, indentation consistency,
# block balance, and parse errors

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"
const CORE_ROOT := SRC_ROOT + "/core"

class ConfidenceResult:
	var score: float = 0.0
	var components: Dictionary = {}
	var capped: bool = false
	var cap_reason: String = ""
	
	func _init():
		components = {
			"token_coverage": 0.0,
			"indentation_consistency": 0.0,
			"block_balance": 0.0,
			"parse_errors": 0.0
		}

var default_weights: Dictionary = {
	# Tuned via tests/validate_confidence.gd (r^2 > 0.7)
	"token_coverage": 0.0,
	"indentation_consistency": 0.0,
	"block_balance": 0.0,
	"parse_errors": 1.0
}

var result: ConfidenceResult

func calculate_confidence(tokens: Array, errors: Array, version_adapter = null, weights: Dictionary = {}) -> ConfidenceResult:
	result = ConfidenceResult.new()
	
	if tokens.size() == 0:
		result.score = 0.0
		return result
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var token_coverage = _calculate_token_coverage(tokens)
	var indentation_consistency = _calculate_indentation_consistency(tokens)
	var block_balance = _calculate_block_balance(tokens)
	var parse_error_score = _calculate_parse_error_score(errors, tokens.size())
	
	result.components["token_coverage"] = token_coverage
	result.components["indentation_consistency"] = indentation_consistency
	result.components["block_balance"] = block_balance
	result.components["parse_errors"] = parse_error_score
	
	var effective_weights = _normalize_weights(weights)
	result.score = (
		token_coverage * effective_weights["token_coverage"] +
		indentation_consistency * effective_weights["indentation_consistency"] +
		block_balance * effective_weights["block_balance"] +
		parse_error_score * effective_weights["parse_errors"]
	)
	
	result.score = clamp(result.score, 0.0, 1.0)
	
	if version_adapter != null:
		var cap = version_adapter.get_confidence_cap()
		if result.score > cap:
			result.capped = true
			result.cap_reason = "Godot %s max confidence cap" % version_adapter.get_version_string()
			result.score = cap
	
	return result

func _normalize_weights(weights: Dictionary) -> Dictionary:
	var merged = default_weights.duplicate()
	if weights != null:
		for key in weights.keys():
			if merged.has(key) and weights[key] is float:
				merged[key] = float(weights[key])
			elif merged.has(key) and weights[key] is int:
				merged[key] = float(weights[key])
	
	var total = 0.0
	for key in merged.keys():
		total += merged[key]
	
	if total <= 0.0:
		return default_weights.duplicate()
	
	for key in merged.keys():
		merged[key] = merged[key] / total
	
	return merged

func _calculate_token_coverage(tokens: Array) -> float:
	if tokens.size() == 0:
		return 0.0
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var total_chars = 0
	var recognized_chars = 0
	
	for token in tokens:
		var token_length = token.value.length()
		total_chars += token_length
		
		if token.type != TokenType.WHITESPACE:
			recognized_chars += token_length
	
	if total_chars == 0:
		return 1.0
	
	return float(recognized_chars) / float(total_chars)

func _calculate_indentation_consistency(tokens: Array) -> float:
	if tokens.size() == 0:
		return 1.0
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var indent_levels: Array = []
	var has_tabs = false
	var has_spaces = false
	var mixed_lines = 0
	var total_lines = 0
	var last_line = -1
	
	for token in tokens:
		if token.type == TokenType.WHITESPACE:
			if token.line != last_line:
				total_lines += 1
				last_line = token.line
				
				var indent = _count_indent(token.value)
				if indent > 0:
					var line_has_tabs = false
					var line_has_spaces = false
					
					for i in range(token.value.length()):
						if token.value[i] == "\t":
							line_has_tabs = true
						elif token.value[i] == " ":
							line_has_spaces = true
					
					if line_has_tabs and line_has_spaces:
						mixed_lines += 1
					elif line_has_tabs:
						has_tabs = true
					elif line_has_spaces:
						has_spaces = true
	
	if total_lines == 0:
		return 1.0
	
	if has_tabs and has_spaces:
		mixed_lines += 1
	
	var consistency = 1.0 - (float(mixed_lines) / float(total_lines))
	return max(0.0, consistency)

func _count_indent(whitespace: String) -> int:
	if whitespace.length() == 0:
		return 0
	
	var count = 0
	for i in range(whitespace.length()):
		if whitespace[i] == "\t" or whitespace[i] == " ":
			count += 1
		else:
			break
	
	return count

func _calculate_block_balance(tokens: Array) -> float:
	if tokens.size() == 0:
		return 1.0
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var paren_depth = 0
	var bracket_depth = 0
	var brace_depth = 0
	var max_paren_depth = 0
	var max_bracket_depth = 0
	var max_brace_depth = 0
	var unbalanced = false
	
	for token in tokens:
		if token.type == TokenType.OPERATOR:
			if token.value == "(":
				paren_depth += 1
				max_paren_depth = max(max_paren_depth, paren_depth)
			elif token.value == ")":
				paren_depth -= 1
				if paren_depth < 0:
					unbalanced = true
			elif token.value == "[":
				bracket_depth += 1
				max_bracket_depth = max(max_bracket_depth, bracket_depth)
			elif token.value == "]":
				bracket_depth -= 1
				if bracket_depth < 0:
					unbalanced = true
			elif token.value == "{":
				brace_depth += 1
				max_brace_depth = max(max_brace_depth, brace_depth)
			elif token.value == "}":
				brace_depth -= 1
				if brace_depth < 0:
					unbalanced = true
	
	if unbalanced:
		return 0.0
	
	var total_open = max_paren_depth + max_bracket_depth + max_brace_depth
	if total_open == 0:
		return 1.0
	
	var balance_score = 1.0
	if paren_depth != 0:
		balance_score *= 0.5
	if bracket_depth != 0:
		balance_score *= 0.5
	if brace_depth != 0:
		balance_score *= 0.5
	
	return balance_score

func _calculate_parse_error_score(errors: Array, token_count: int) -> float:
	if token_count == 0:
		return 0.0
	
	var error_count = errors.size()
	var error_ratio = float(error_count) / float(token_count)
	
	var score = 1.0 - min(1.0, error_ratio * 10.0)
	return max(0.0, score)

func get_score() -> float:
	if result == null:
		return 0.0
	return result.score

func get_components() -> Dictionary:
	if result == null:
		return {}
	return result.components.duplicate()

func is_capped() -> bool:
	if result == null:
		return false
	return result.capped

func get_cap_reason() -> String:
	if result == null:
		return ""
	return result.cap_reason


func _tokenizer_script_path() -> String:
	var major = Engine.get_version_info().get("major", 0)
	if major < 4:
		return SRC_ROOT + "/gd3/tokenizer.gd"
	return SRC_ROOT + "/tokenizer.gd"
