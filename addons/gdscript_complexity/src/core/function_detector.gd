extends Object
# class_name FunctionDetector

# function boundary detector for
# detects: func, static func, signal declarations
# uses indentation to determine function boundaries

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src"
const CORE_ROOT := SRC_ROOT + "/core"

class FunctionInfo:
	var name: String
	var type: String 
	var start_line: int
	var start_column: int
	var end_line: int
	var parameters: Array = []
	var return_type: String = ""
	var ignored: bool = false
	var pinned: bool = false
	
	func _init(n: String, t: String, line: int, col: int):
		name = n
		type = t
		start_line = line
		start_column = col
		end_line = line
		ignored = false
		pinned = false
	
	func _to_string() -> String:
		return "%s %s() at %d:%d-%d" % [type, name, start_line, start_column, end_line]

var functions: Array = []
var errors: Array = []

func detect_functions(tokens: Array) -> Array:
	functions.clear()
	errors.clear()
	
	if tokens.size() == 0:
		return []
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	
	var i = 0
	var current_function: FunctionInfo = null
	var function_indent = -1
	
	while i < tokens.size():
		var token = tokens[i]

		if token.type == TokenType.WHITESPACE:
			var indent = _count_indent(token.value)

			if current_function != null and indent >= 0 and indent <= function_indent:
				current_function.end_line = token.line - 1
				current_function = null
				function_indent = -1
			
			i += 1
			continue
		
		if token.type == TokenType.COMMENT:
			i += 1
			continue

		if token.type == TokenType.KEYWORD:
			if token.value == "func" or token.value == "static":
				var func_result = _parse_function_declaration(tokens, i)
				if func_result.function != null:
					if current_function != null:
						current_function.end_line = token.line - 1
					
					current_function = func_result.function
					function_indent = _get_line_indent(tokens, i)
					functions.append(current_function)
					i = func_result.next_index
					continue
			elif token.value == "signal":
				var signal_result = _parse_signal_declaration(tokens, i)
				if signal_result.function != null:
					if current_function != null:
						current_function.end_line = token.line - 1
					
					current_function = signal_result.function
					function_indent = _get_line_indent(tokens, i)
					functions.append(current_function)
					i = signal_result.next_index
					continue
		
		i += 1

	if current_function != null:
		if tokens.size() > 0:
			current_function.end_line = tokens[tokens.size() - 1].line
		else:
			current_function.end_line = current_function.start_line
	
	return functions.duplicate()

func _get_line_indent(tokens: Array, token_index: int) -> int:

	if token_index <= 0:
		return 0
	
	var TokenType = load(_tokenizer_script_path()).TokenType
	var target_line = tokens[token_index].line
	var i = token_index - 1
	
	while i >= 0:
		var token = tokens[i]
		if token.line != target_line:
			break
		if token.type == TokenType.WHITESPACE:
			return _count_indent(token.value)
		i -= 1
	
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

func _parse_function_declaration(tokens: Array, start: int) -> Dictionary:

	var TokenType = load(_tokenizer_script_path()).TokenType
	var i = start
	var func_type = "func"
	var func_name = ""
	var params: Array = []
	var return_type = ""

	if tokens[i].value == "static":
		func_type = "static_func"
		i += 1
		while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
			i += 1
	
	if i >= tokens.size() or tokens[i].value != "func":
		return {"function": null, "next_index": start + 1}
	
	var func_line = tokens[i].line
	var func_col = tokens[i].column
	i += 1

	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1

	if i >= tokens.size() or tokens[i].type != TokenType.IDENTIFIER:
		return {"function": null, "next_index": start + 1}
	
	func_name = tokens[i].value
	i += 1

	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1

	if i < tokens.size() and tokens[i].value == "(":
		i += 1
		var param_count = 0
		var depth = 1
		
		while i < tokens.size() and depth > 0:
			if tokens[i].value == "(":
				depth += 1
			elif tokens[i].value == ")":
				depth -= 1
			elif tokens[i].value == "," and depth == 1:
				param_count += 1
			i += 1
		
		params.resize(param_count + 1)

	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1

	if i < tokens.size() and tokens[i].type == TokenType.OPERATOR and tokens[i].value == "->":
		i += 1
		while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
			i += 1
		if i < tokens.size() and (tokens[i].type == TokenType.IDENTIFIER or tokens[i].type == TokenType.KEYWORD):
			return_type = tokens[i].value
			i += 1
			# Typed collections: Array[int], Dictionary, etc.
			while i < tokens.size() and tokens[i].type == TokenType.OPERATOR and tokens[i].value == "[":
				return_type += "["
				i += 1
				while i < tokens.size() and tokens[i].value != "]":
					if tokens[i].type != TokenType.WHITESPACE:
						return_type += tokens[i].value
					i += 1
				if i < tokens.size() and tokens[i].value == "]":
					return_type += "]"
					i += 1
	
	var func_info = FunctionInfo.new(func_name, func_type, func_line, func_col)
	func_info.parameters = params
	func_info.return_type = return_type
	
	return {"function": func_info, "next_index": i}

func _parse_signal_declaration(tokens: Array, start: int) -> Dictionary:
	var TokenType = load(_tokenizer_script_path()).TokenType
	var i = start + 1  # Skip "signal"
	var signal_name = ""
	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1
	if i >= tokens.size() or tokens[i].type != TokenType.IDENTIFIER:
		return {"function": null, "next_index": start + 1}
	
	signal_name = tokens[i].value
	var signal_line = tokens[i].line
	var signal_col = tokens[i].column
	i += 1
	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1
	var params: Array = []
	if i < tokens.size() and tokens[i].value == "(":
		i += 1
		var param_count = 0
		var depth = 1
		while i < tokens.size() and depth > 0:
			if tokens[i].value == "(":
				depth += 1
			elif tokens[i].value == ")":
				depth -= 1
			elif tokens[i].value == "," and depth == 1:
				param_count += 1
			i += 1
		
		params.resize(param_count + 1)
	
	var func_info = FunctionInfo.new(signal_name, "signal", signal_line, signal_col)
	func_info.parameters = params
	
	return {"function": func_info, "next_index": i}

func get_errors() -> Array:
	return errors.duplicate()



func _tokenizer_script_path() -> String:
	var major = Engine.get_version_info().get("major", 0)
	if major < 4:
		return SRC_ROOT + "/gd3/tokenizer.gd"
	return SRC_ROOT + "/tokenizer.gd"
