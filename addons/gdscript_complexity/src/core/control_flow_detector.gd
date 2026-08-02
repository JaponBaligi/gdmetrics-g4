extends Object
# class_name ControlFlowDetector

# Control flow detector 
# Detects: if, elif, for, while, match/case, and logical operators
# Tracks indentation-based nesting depth for C-COG calculations

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"
const CORE_ROOT := SRC_ROOT + "/core"

class ControlFlowNode:
	var type: String
	var line: int
	var column: int
	var depth: int = 0
	var in_control_flow: bool = false
	var lambda_depth: int = 0
	var case_pattern_count: int = 1
	var case_has_guard: bool = false
	
	func _init(t: String, l: int, c: int, d: int = 0):
		type = t
		line = l
		column = c
		depth = d
	
	func _to_string() -> String:
		return "%s at %d:%d (depth: %d)" % [type, line, column, depth]

var detected_nodes: Array = []
var errors: Array = []
var in_match_block: bool = false
var version_adapter = null

func detect_control_flow(tokens: Array, adapter = null) -> Array:
	detected_nodes.clear()
	errors.clear()
	in_match_block = false
	version_adapter = adapter
	
	if tokens.size() == 0:
		return []
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var supports_match = true
	if version_adapter != null:
		supports_match = version_adapter.supports_match_statements()
	
	var i = 0
	var indent_stack: Array = []  # Stack of indentation levels
	var control_flow_stack: Array = []  # Stack of control flow contexts: {indent, type}
	var lambda_stack: Array = []  # Stack of lambda *header* indents (body is deeper)
	var last_line = -1
	var last_line_indent = 0
	var match_arm_lines: Dictionary = {}  # line -> true, avoid double-count
	
	while i < tokens.size():
		var token = tokens[i]
		
		if token.type == TokenType.NEWLINE:
			last_line = token.line
			last_line_indent = 0
			i += 1
			continue
		
		if token.type == TokenType.WHITESPACE:
			if token.line != last_line:
				var indent = _count_indent(token.value)
				if indent >= 0:
					last_line_indent = indent
					last_line = token.line
					_update_indent_stack(indent_stack, last_line_indent)
					_update_control_flow_stack(control_flow_stack, last_line_indent)
					in_match_block = _is_match_active(control_flow_stack)
					_update_lambda_stack(lambda_stack, last_line_indent)
			i += 1
			continue
		
		if token.type == TokenType.COMMENT:
			i += 1
			continue

		# Detect real GDScript match arms (no `case` keyword): indent under match + `:` on line
		if supports_match and in_match_block and not match_arm_lines.has(token.line):
			var line_indent_arm = _get_line_indent(tokens, i)
			var match_entry = _get_innermost_match_entry(control_flow_stack)
			if match_entry != null:
				var match_indent = int(match_entry.get("indent", -1))
				if match_indent >= 0 and line_indent_arm > match_indent:
					var arm_indent = int(match_entry.get("arm_indent", -1))
					if arm_indent < 0:
						match_entry["arm_indent"] = line_indent_arm
						arm_indent = line_indent_arm
					if line_indent_arm == arm_indent and _line_is_match_arm(tokens, i):
						var details = _parse_match_arm_details(tokens, i)
						var nesting_depth_arm = indent_stack.size()
						var node_arm = ControlFlowNode.new("case", token.line, token.column, nesting_depth_arm)
						node_arm.in_control_flow = control_flow_stack.size() > 0
						node_arm.lambda_depth = lambda_stack.size()
						node_arm.case_pattern_count = details.pattern_count
						node_arm.case_has_guard = details.has_guard
						detected_nodes.append(node_arm)
						match_arm_lines[token.line] = true
						control_flow_stack.append({"indent": line_indent_arm, "type": "case"})
		
		if token.type == TokenType.KEYWORD:
			var line_indent = _get_line_indent(tokens, i)
			# Only structural keywords may mutate indent/control-flow stacks.
			# Mid-line keywords like `in`/`as` must not pop a just-opened `for`/`if`.
			var structural = token.value in ["if", "elif", "for", "while", "match", "func"]
			if structural:
				_update_indent_stack(indent_stack, line_indent)
				_update_control_flow_stack(control_flow_stack, line_indent)
				in_match_block = _is_match_active(control_flow_stack)
				_update_lambda_stack(lambda_stack, line_indent)
			var nesting_depth = indent_stack.size()
			var in_control_flow = control_flow_stack.size() > 0
			var lambda_depth = lambda_stack.size()
			
			if token.value == "if":
				var is_ternary = _is_ternary_if(tokens, i)
				var node_type = "ternary" if is_ternary else "if"
				var node = ControlFlowNode.new(node_type, token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				if not is_ternary:
					control_flow_stack.append({"indent": line_indent, "type": "if"})
			elif token.value == "elif":
				var node = ControlFlowNode.new("elif", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "elif"})
			elif token.value == "for":
				var node = ControlFlowNode.new("for", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "for"})
			elif token.value == "while":
				var node = ControlFlowNode.new("while", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "while"})
			elif token.value == "match" and supports_match and _is_match_statement(tokens, i):
				var node = ControlFlowNode.new("match", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				in_match_block = true
				control_flow_stack.append({"indent": line_indent, "type": "match", "arm_indent": -1})
			elif token.value == "and":
				var node = ControlFlowNode.new("and", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "or":
				var node = ControlFlowNode.new("or", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "not":
				var node = ControlFlowNode.new("not", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "return" or token.value == "break" or token.value == "continue":
				var node = ControlFlowNode.new(token.value, token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "func":
				var anon = _is_anonymous_func(tokens, i)
				if anon:
					var node = ControlFlowNode.new("lambda", token.line, token.column, nesting_depth)
					node.in_control_flow = in_control_flow
					node.lambda_depth = lambda_depth
					detected_nodes.append(node)
					# Header indent: body lines are deeper; pop when indent returns to header.
					lambda_stack.append(line_indent)

		# C-style logical operators (counted when config enables it in CC calculator)
		if token.type == TokenType.OPERATOR and (token.value == "&&" or token.value == "||"):
			var nesting_depth_op = indent_stack.size()
			var op_type = "and" if token.value == "&&" else "or"
			var node_op = ControlFlowNode.new(op_type, token.line, token.column, nesting_depth_op)
			node_op.in_control_flow = control_flow_stack.size() > 0
			node_op.lambda_depth = lambda_stack.size()
			detected_nodes.append(node_op)
		
		i += 1
	
	return detected_nodes.duplicate()

func _get_line_indent(tokens: Array, token_index: int) -> int:
	if token_index < 0 or token_index >= tokens.size():
		return 0

	var TokenType = load(_tokenizer_script_path()).TokenType
	var target_line = tokens[token_index].line
	# Leading indent only — not mid-line spaces (e.g. `return func():` / `a if b else c`).
	var i = token_index
	while i > 0 and tokens[i - 1].line == target_line:
		i -= 1
	if tokens[i].type == TokenType.WHITESPACE:
		return _count_indent(tokens[i].value)
	return 0

func _count_indent(whitespace: String) -> int:
	if whitespace.length() == 0:
		return 0
	
	var has_tabs = false
	var has_spaces = false
	var count = 0
	
	for i in range(whitespace.length()):
		if whitespace[i] == "\t":
			has_tabs = true
			count += 1
		elif whitespace[i] == " ":
			has_spaces = true
			count += 1
	
	if has_tabs and has_spaces:
		return -1
	
	return count

func _update_indent_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1] >= current_indent:
		stack.pop_back()
	
	if stack.size() == 0 or stack[stack.size() - 1] < current_indent:
		if current_indent > 0:
			stack.append(current_indent)

func _update_control_flow_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1]["indent"] >= current_indent:
		stack.pop_back()

func _update_lambda_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1] >= current_indent:
		stack.pop_back()

func _is_match_active(stack: Array) -> bool:
	for entry in stack:
		if entry.get("type", "") == "match":
			return true
	return false

func _get_match_indent(stack: Array) -> int:
	var entry = _get_innermost_match_entry(stack)
	if entry == null:
		return -1
	return int(entry.get("indent", 0))

func _get_innermost_match_entry(stack: Array):
	for idx in range(stack.size() - 1, -1, -1):
		if stack[idx].get("type", "") == "match":
			return stack[idx]
	return null

func _is_match_statement(tokens: Array, match_index: int) -> bool:
	# Reject method calls like `text.match(pattern)` — statement match has no `.` immediately before it
	var TokenType = load(_tokenizer_script_path()).TokenType
	var i = match_index - 1
	while i >= 0:
		var t = tokens[i]
		if t.type == TokenType.WHITESPACE or t.type == TokenType.COMMENT:
			i -= 1
			continue
		if t.type == TokenType.OPERATOR and t.value == ".":
			return false
		return true
	return true

func _is_ternary_if(tokens: Array, if_index: int) -> bool:
	# Statement `if` is first non-ws token on its line; ternary has tokens before it
	var TokenType = load(_tokenizer_script_path()).TokenType
	var line = tokens[if_index].line
	var i = if_index - 1
	while i >= 0 and tokens[i].line == line:
		if tokens[i].type != TokenType.WHITESPACE and tokens[i].type != TokenType.COMMENT:
			return true
		i -= 1
	return false

func _line_is_match_arm(tokens: Array, start_index: int) -> bool:
	var TokenType = load(_tokenizer_script_path()).TokenType
	var line = tokens[start_index].line
	var paren_depth = 0
	var i = start_index
	# Skip leading statement keywords that cannot start an arm body header incorrectly —
	# arms may start with var/_, numbers, strings, [, {, identifiers
	while i < tokens.size() and tokens[i].line == line:
		var token = tokens[i]
		if token.type == TokenType.OPERATOR:
			if token.value == "(" or token.value == "[" or token.value == "{":
				paren_depth += 1
			elif token.value == ")" or token.value == "]" or token.value == "}":
				if paren_depth > 0:
					paren_depth -= 1
			elif token.value == ":" and paren_depth == 0:
				return true
		i += 1
	return false

func _parse_match_arm_details(tokens: Array, start_index: int) -> Dictionary:
	var TokenType = load(_tokenizer_script_path()).TokenType
	var pattern_count = 1
	var has_guard = false
	var guard_mode = false
	var paren_depth = 0
	var line = tokens[start_index].line
	var i = start_index
	
	while i < tokens.size():
		var token = tokens[i]
		if token.line != line:
			break
		if token.type == TokenType.OPERATOR and token.value == ":" and paren_depth == 0:
			break
		if token.type == TokenType.OPERATOR:
			if token.value == "(" or token.value == "[" or token.value == "{":
				paren_depth += 1
			elif token.value == ")" or token.value == "]" or token.value == "}":
				if paren_depth > 0:
					paren_depth -= 1
			elif token.value == "," and paren_depth == 0 and not guard_mode:
				pattern_count += 1
		elif token.type == TokenType.KEYWORD and paren_depth == 0:
			if token.value == "when" or token.value == "if":
				has_guard = true
				guard_mode = true
		i += 1
	
	return {
		"pattern_count": pattern_count,
		"has_guard": has_guard
	}

func _parse_case_details(tokens: Array, start_index: int) -> Dictionary:
	return _parse_match_arm_details(tokens, start_index)

func _is_anonymous_func(tokens: Array, func_index: int) -> bool:
	var TokenType = load(_tokenizer_script_path()).TokenType
	var i = func_index + 1
	while i < tokens.size():
		var token = tokens[i]
		if token.type == TokenType.WHITESPACE or token.type == TokenType.COMMENT:
			i += 1
			continue
		if token.type == TokenType.IDENTIFIER:
			return false
		if token.type == TokenType.OPERATOR and token.value == "(":
			return true
		return false
	return false

func get_errors() -> Array:
	return errors.duplicate()

func count_by_type(type: String) -> int:
	var count = 0
	for node in detected_nodes:
		if node.type == type:
			count += 1
	return count


func _tokenizer_script_path() -> String:
	var major = Engine.get_version_info().get("major", 0)
	if major < 4:
		return SRC_ROOT + "/gd3/tokenizer.gd"
	return SRC_ROOT + "/tokenizer.gd"
