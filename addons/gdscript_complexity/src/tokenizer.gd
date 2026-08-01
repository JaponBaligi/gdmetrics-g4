extends Object


# Tokenizer for GDScript (Godot 4.x)
# Keywords, identifiers, operators, comments, strings, numbers 

const ADDON_ROOT := "res://addons/gdscript_complexity"
const SRC_ROOT := ADDON_ROOT + "/src" 

var file_helper = null

func _init():
	file_helper = load(SRC_ROOT + "/gd4/file_helper.gd").new()

enum TokenType {
	KEYWORD,
	IDENTIFIER,
	OPERATOR,
	NUMBER,
	STRING,
	COMMENT,
	WHITESPACE,
	NEWLINE
}

class Token:
	var type: int
	var value: String
	var line: int
	var column: int
	
	func _init(t: int, v: String, l: int, c: int):
		type = t
		value = v
		line = l
		column = c
	
	func _to_string() -> String:
		return "Token(%s, '%s', %d:%d)" % [TokenType.keys()[type], value, line, column]

const KEYWORDS = [
	"if", "elif", "else", "for", "while", "break", "continue", "return",
	"func", "class", "extends", "var", "const", "signal", "class_name",
	"and", "or", "not", "true", "false", "null",
	"pass", "self", "super", "match", "yield", "await",
	"in", "is", "as", "enum", "assert", "breakpoint", "preload", "load",
	"static", "void", "tool", "onready", "export", "setget",
	"master", "puppet", "remote", "sync", "remotesync", "mastersync", "puppetsync"
]

# `$` is GDScript node-path shorthand ($Node, $"Node Path")
const SINGLE_OPS = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ".", ",", ";", "(", ")", "[", "]", "{", "}", "$"]

const DOUBLE_OPS = ["==", "!=", "<=", ">=", "&&", "||", "->", "::", "..", "+=", "-=", "*=", "/=", "%=", "**", "<<", ">>"]

var tokens: Array = []
var errors: Array = []
var _error_codes = null

var in_multiline_comment: bool = false
var in_triple_string: bool = false
var triple_string_quote: String = ""
var multiline_buffer: String = ""
var multiline_start_line: int = 1
var paren_depth: int = 0
var bracket_depth: int = 0
var brace_depth: int = 0
var line_continuation_pending: bool = false

func tokenize_file(file_path: String) -> Array:

	tokens.clear()
	errors.clear()
	in_multiline_comment = false
	in_triple_string = false
	triple_string_quote = ""
	multiline_buffer = ""
	multiline_start_line = 1
	paren_depth = 0
	bracket_depth = 0
	brace_depth = 0
	line_continuation_pending = false
	
	if file_helper == null:
		file_helper = load(SRC_ROOT + "/gd4/file_helper.gd").new()
	
	var file = file_helper.open_read(file_path)
	if file == null:
		if not file_helper.file_exists(file_path):
			_append_error("FILE_NOT_FOUND", "File not found: %s" % file_path)
		else:
			_append_error("FILE_OPEN_FAILED", "Failed to open file: %s" % file_path)
		return []
	
	var line_number = 1
	while not file.eof_reached():
		var line = file.get_line()
		# Strip UTF-8 BOM on first line
		if line_number == 1 and line.length() > 0 and line.unicode_at(0) == 0xFEFF:
			line = line.substr(1)
		if line_continuation_pending:
			var stripped = line.strip_edges()
			if stripped == "" or stripped.begins_with("#"):
				# Engine skips blank/comment lines after `\` (GH-89403)
				if stripped.begins_with("#"):
					tokens.append(Token.new(TokenType.COMMENT, stripped, line_number, 1))
				line_number += 1
				continue
			line_continuation_pending = false
		# Multi-line comments have no line-continuation semantics.
		# Open strings (triple or regular multi-line) must still be scanned so a `\`
		# *after* the closer counts as line continuation.
		if in_multiline_comment:
			tokenize_line(line, line_number)
		else:
			var is_triple_delim = in_triple_string and triple_string_quote.length() == 3
			var cont = _split_line_continuation(line, in_triple_string, triple_string_quote, is_triple_delim)
			if cont.invalid:
				_append_error("TOKEN_PARSE_ERROR", "Line %d:%d: Expected new line after \"\\\"." % [line_number, cont.column])
				tokenize_line(cont.code, line_number)
			else:
				tokenize_line(cont.code, line_number)
				if cont.continues:
					line_continuation_pending = true
		line_number += 1
	
	file_helper.close_file(file)
	
	if in_multiline_comment:
		_append_error("TOKEN_UNTERMINATED_COMMENT", "Unterminated multi-line comment starting at line %d" % multiline_start_line)
	if in_triple_string:
		_append_error("TOKEN_UNTERMINATED_STRING", "Unterminated string starting at line %d" % multiline_start_line)
	if paren_depth != 0:
		_append_error("TOKEN_UNBALANCED_PAREN", "Unbalanced parentheses in file")
	if bracket_depth != 0:
		_append_error("TOKEN_UNBALANCED_BRACKET", "Unbalanced brackets in file")
	if brace_depth != 0:
		_append_error("TOKEN_UNBALANCED_BRACE", "Unbalanced braces in file")
	
	return tokens.duplicate()

func tokenize_line(line: String, line_number: int):
	if in_multiline_comment:
		var result = _continue_multiline_comment(line, line_number)
		if result.complete:
			in_multiline_comment = false
			multiline_buffer = ""
			_tokenize_line_body(line, line_number, result.next_index, result.next_column)
		return

	if in_triple_string:
		var result = _continue_triple_string(line, line_number)
		if result.complete:
			in_triple_string = false
			triple_string_quote = ""
			multiline_buffer = ""
			_tokenize_line_body(line, line_number, result.next_index, result.next_column)
		return

	_tokenize_line_body(line, line_number, 0, 1)

func _tokenize_line_body(line: String, line_number: int, start_i: int, start_col: int):
	var i = start_i
	var column = start_col

	while i < line.length():
		var current_char = line[i]
		if current_char in " \t":
			var ws_col = column
			while i < line.length() and line[i] in " \t":
				i += 1
				column += 1
			tokens.append(Token.new(TokenType.WHITESPACE, line.substr(ws_col - 1, i - ws_col + 1), line_number, ws_col))
			continue

		if i + 2 < line.length():
			var three_chars = line.substr(i, 3)
			if three_chars == '"""' or three_chars == "'''":
				var result = _parse_triple_string(line, i, line_number, column, three_chars)
				if result.error:
					_append_error("TOKEN_PARSE_ERROR", "Line %d:%d: %s" % [line_number, column, result.error])
					i += 1
					column += 1
				elif result.multiline:
					in_triple_string = true
					triple_string_quote = three_chars
					multiline_buffer = result.token.value
					multiline_start_line = line_number
					return
				else:
					tokens.append(result.token)
					i = result.next_index
					column = result.next_column
				continue

		if current_char == "#":
			var comment_text = line.substr(i)
			tokens.append(Token.new(TokenType.COMMENT, comment_text, line_number, column))
			break

		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			var result = _parse_multiline_comment(line, i, line_number, column)
			if result.multiline:
				in_multiline_comment = true
				multiline_buffer = result.token.value
				multiline_start_line = line_number
				return
			else:
				tokens.append(result.token)
				i = result.next_index
				column = result.next_column
			continue

		if current_char == '"' or current_char == "'":
			var string_result = _parse_string(line, i, line_number, column, current_char)
			if string_result.error != "":
				_append_error("TOKEN_PARSE_ERROR", "Line %d:%d: %s" % [line_number, column, string_result.error])
				i += 1
				column += 1
			elif string_result.multiline:
				# Godot 4 allows newlines inside regular "…" / '…' strings
				in_triple_string = true
				triple_string_quote = current_char
				multiline_buffer = string_result.token.value
				multiline_start_line = line_number
				return
			else:
				tokens.append(string_result.token)
				i = string_result.next_index
				column = string_result.next_column
			continue

		if (current_char >= "0" and current_char <= "9") or (current_char == "." and i + 1 < line.length() and line[i + 1] >= "0" and line[i + 1] <= "9"):
			var number_result = _parse_number(line, i, line_number, column)
			tokens.append(number_result.token)
			i = number_result.next_index
			column = number_result.next_column
			continue

		if i + 1 < line.length():
			var two_char = line.substr(i, 2)
			if two_char in DOUBLE_OPS:
				tokens.append(Token.new(TokenType.OPERATOR, two_char, line_number, column))
				i += 2
				column += 2
				continue
		
		# StringName / NodePath literals: &"…"  ^"…"  @"…"
		if (current_char == "&" or current_char == "^" or current_char == "@") and i + 1 < line.length() and (line[i + 1] == '"' or line[i + 1] == "'"):
			var pref = current_char
			var q = line[i + 1]
			var str_res = _parse_string(line, i + 1, line_number, column + 1, q)
			if str_res.error == "":
				if str_res.multiline:
					in_triple_string = true
					triple_string_quote = q
					multiline_buffer = pref + str_res.token.value
					multiline_start_line = line_number
					return
				var lit = Token.new(TokenType.STRING, pref + str_res.token.value, line_number, column)
				tokens.append(lit)
				i = str_res.next_index
				column = column + pref.length() + str_res.token.value.length()
				continue

		# Raw strings: r"…" / r'…' / r"""…"""
		if (current_char == "r" or current_char == "R") and i + 1 < line.length():
			var nch = line[i + 1]
			if nch == '"' or nch == "'":
				if i + 3 < line.length() and line.substr(i + 1, 3) == nch + nch + nch:
					var tres = _parse_triple_string(line, i + 1, line_number, column + 1, nch + nch + nch)
					if tres.error:
						_append_error("TOKEN_PARSE_ERROR", "Line %d:%d: %s" % [line_number, column, tres.error])
						i += 1
						column += 1
					elif tres.multiline:
						in_triple_string = true
						triple_string_quote = nch + nch + nch
						multiline_buffer = "r" + tres.token.value
						multiline_start_line = line_number
						return
					else:
						tokens.append(Token.new(TokenType.STRING, "r" + tres.token.value, line_number, column))
						i = tres.next_index
						column = column + 1 + tres.token.value.length()
					continue
				var rres = _parse_raw_string(line, i + 1, line_number, column + 1, nch)
				if rres.error == "":
					tokens.append(Token.new(TokenType.STRING, "r" + rres.token.value, line_number, column))
					i = rres.next_index
					column = column + 1 + rres.token.value.length()
					continue

		if current_char in SINGLE_OPS:
			tokens.append(Token.new(TokenType.OPERATOR, current_char, line_number, column))
			_track_brackets(current_char, line_number, column)
			i += 1
			column += 1
			continue

		if (current_char >= "a" and current_char <= "z") or (current_char >= "A" and current_char <= "Z") or (current_char >= "0" and current_char <= "9") or current_char == "_":
			var ident_result = _parse_identifier(line, i, line_number, column)
			tokens.append(ident_result.token)
			i = ident_result.next_index
			column = ident_result.next_column
			continue

		if current_char == "@":
			var annotation_result = _parse_annotation(line, i, line_number, column)
			if annotation_result.found:
				tokens.append(annotation_result.token)
				i = annotation_result.next_index
				column = annotation_result.next_column
				continue

		# Soft-accept non-ASCII as identifier characters
		if current_char.length() > 0 and current_char.unicode_at(0) > 127:
			var uid = _parse_identifier(line, i, line_number, column)
			if uid.next_index > i:
				tokens.append(uid.token)
				i = uid.next_index
				column = uid.next_column
				continue

		_append_error("TOKEN_UNKNOWN_CHAR", "Line %d:%d: Unknown character '%s'" % [line_number, column, current_char])
		i += 1
		column += 1

func _split_line_continuation(line: String, start_in_str: bool = false, start_quote: String = "", start_triple: bool = false) -> Dictionary:
	# Returns {code, continues, invalid, column}. Outside strings, `\` must be last non-ws.
	var i = 0
	var in_str = start_in_str
	var quote = start_quote
	var triple = start_triple
	var escaped = false
	while i < line.length():
		var c = line[i]
		if in_str:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif triple:
				if i + 2 < line.length() and line.substr(i, 3) == quote:
					in_str = false
					quote = ""
					triple = false
					i += 3
					continue
			elif c == quote:
				in_str = false
				quote = ""
			i += 1
			continue
		if c == "#":
			break
		if (c == '"' or c == "'") and i + 2 < line.length() and line[i + 1] == c and line[i + 2] == c:
			in_str = true
			triple = true
			quote = c + c + c
			i += 3
			continue
		if c == '"' or c == "'":
			in_str = true
			triple = false
			quote = c
			i += 1
			continue
		if c == "\\":
			var j = i + 1
			while j < line.length() and (line[j] == " " or line[j] == "\t"):
				j += 1
			if j >= line.length():
				return {"code": line.substr(0, i), "continues": true, "invalid": false, "column": i + 1}
			# Mid-line backslash: drop it and flag error
			return {
				"code": line.substr(0, i) + line.substr(i + 1),
				"continues": false,
				"invalid": true,
				"column": i + 1
			}
		i += 1
	return {"code": line, "continues": false, "invalid": false, "column": 1}

func _parse_string(line: String, start: int, line_num: int, col: int, quote_char: String) -> Dictionary:

	var i = start + 1
	var value = quote_char
	var escaped = false
	
	while i < line.length():
		var current_char = line[i]
		
		if escaped:
			if current_char == "n":
				value += "\\n"
			elif current_char == "t":
				value += "\\t"
			elif current_char == "r":
				value += "\\r"
			elif current_char == "a" or current_char == "b" or current_char == "f" or current_char == "v":
				value += "\\" + current_char
			elif current_char == "\\":
				value += "\\\\"
			elif current_char == quote_char:
				value += "\\" + quote_char
			elif current_char == "u":
				value += "\\u"
				i += 1
				var u = 0
				while u < 4 and i < line.length() and _is_hex_digit(line[i]):
					value += line[i]
					i += 1
					u += 1
				escaped = false
				continue
			elif current_char == "U":
				value += "\\U"
				i += 1
				var U = 0
				while U < 6 and i < line.length() and _is_hex_digit(line[i]):
					value += line[i]
					i += 1
					U += 1
				escaped = false
				continue
			else:
				value += "\\" + current_char
			escaped = false
			i += 1
		elif current_char == "\\":
			escaped = true
			i += 1
		elif current_char == quote_char:
			value += quote_char
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 1, "next_column": col + value.length(), "error": "", "multiline": false}
		else:
			value += current_char
			i += 1

	# Godot 4: regular strings may span lines (newlines become part of the string)
	value += "\n"
	var ml_token = Token.new(TokenType.STRING, value, line_num, col)
	return {
		"token": ml_token,
		"next_index": line.length(),
		"next_column": col + value.length(),
		"error": "",
		"multiline": true
	}

func _parse_raw_string(line: String, start: int, line_num: int, col: int, quote_char: String) -> Dictionary:
	# Raw strings: only \\ and \" / \' are special
	var i = start + 1
	var value = quote_char
	while i < line.length():
		var current_char = line[i]
		if current_char == "\\" and i + 1 < line.length():
			var nxt = line[i + 1]
			if nxt == "\\" or nxt == quote_char:
				value += "\\" + nxt
				i += 2
				continue
			value += current_char
			i += 1
			continue
		if current_char == quote_char:
			value += quote_char
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 1, "next_column": col + value.length(), "error": ""}
		value += current_char
		i += 1
	return {
		"token": null,
		"next_index": i,
		"next_column": col + value.length(),
		"error": "Unterminated raw string literal"
	}

func _is_ident_char(ch: String) -> bool:
	if ch.length() == 0:
		return false
	if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
		return true
	return ch.unicode_at(0) > 127

func _is_hex_digit(ch: String) -> bool:
	return (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F")

func _parse_number(line: String, start: int, line_num: int, col: int) -> Dictionary:

	var i = start
	var value = ""
	
	if i < line.length() and line[i] == "-":
		value += "-"
		i += 1

	# 0x / 0b literals
	if i < line.length() and line[i] == "0" and i + 1 < line.length():
		var base = line[i + 1]
		if base == "x" or base == "X":
			value += "0" + base
			i += 2
			while i < line.length() and (_is_hex_digit(line[i]) or line[i] == "_"):
				value += line[i]
				i += 1
			var token_hex = Token.new(TokenType.NUMBER, value, line_num, col)
			return {"token": token_hex, "next_index": i, "next_column": col + value.length()}
		if base == "b" or base == "B":
			value += "0" + base
			i += 2
			while i < line.length() and (line[i] == "0" or line[i] == "1" or line[i] == "_"):
				value += line[i]
				i += 1
			var token_bin = Token.new(TokenType.NUMBER, value, line_num, col)
			return {"token": token_bin, "next_index": i, "next_column": col + value.length()}
	
	while i < line.length() and ((line[i] >= "0" and line[i] <= "9") or line[i] == "_"):
		value += line[i]
		i += 1
	
	if i < line.length() and line[i] == ".":
		value += "."
		i += 1
		while i < line.length() and ((line[i] >= "0" and line[i] <= "9") or line[i] == "_"):
			value += line[i]
			i += 1

	if i < line.length() and (line[i] == "e" or line[i] == "E"):
		value += line[i]
		i += 1
		if i < line.length() and (line[i] == "+" or line[i] == "-"):
			value += line[i]
			i += 1
		var exp_start = i
		while i < line.length() and ((line[i] >= "0" and line[i] <= "9") or line[i] == "_"):
			value += line[i]
			i += 1
		if i == exp_start:
			var token = Token.new(TokenType.IDENTIFIER, value.substr(0, value.length() - 1), line_num, col)
			return {"token": token, "next_index": exp_start, "next_column": col + value.length() - 1}

	if value == "-" or value == "." or value == "-.":
		var token = Token.new(TokenType.OPERATOR if value == "-" else TokenType.IDENTIFIER, value, line_num, col)
		return {"token": token, "next_index": start + 1, "next_column": col + 1}
	
	var token = Token.new(TokenType.NUMBER, value, line_num, col)
	return {"token": token, "next_index": i, "next_column": col + value.length()}

func _parse_identifier(line: String, start: int, line_num: int, col: int) -> Dictionary:
	var i = start
	var value = ""

	if i < line.length() and _is_ident_char(line[i]) and not (line[i] >= "0" and line[i] <= "9"):
		value += line[i]
		i += 1
		while i < line.length() and _is_ident_char(line[i]):
			value += line[i]
			i += 1
	elif i < line.length() and ((line[i] >= "a" and line[i] <= "z") or (line[i] >= "A" and line[i] <= "Z") or line[i] == "_" or line[i].unicode_at(0) > 127):
		value += line[i]
		i += 1
		while i < line.length() and _is_ident_char(line[i]):
			value += line[i]
			i += 1

	if value == "":
		return {"token": null, "next_index": start, "next_column": col}

	var token_type = TokenType.KEYWORD if value in KEYWORDS else TokenType.IDENTIFIER
	var token = Token.new(token_type, value, line_num, col)
	return {"token": token, "next_index": i, "next_column": col + value.length()}

func _parse_annotation(line: String, start: int, line_num: int, col: int) -> Dictionary:
	# Accept any @identifier so unknown annotations do not abort tokenization
	var miss = {"found": false, "token": null, "next_index": start, "next_column": col}
	if start >= line.length() or line[start] != "@":
		return miss

	var i = start + 1
	if i >= line.length():
		return miss

	var first = line[i]
	if not ((first >= "a" and first <= "z") or (first >= "A" and first <= "Z") or first == "_"):
		return miss

	var value = "@" + first
	i += 1
	while i < line.length():
		var ch = line[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
			value += ch
			i += 1
		else:
			break

	return {
		"found": true,
		"token": Token.new(TokenType.IDENTIFIER, value, line_num, col),
		"next_index": i,
		"next_column": col + value.length()
	}

func get_errors() -> Array:
	return errors.duplicate()

func _parse_multiline_comment(line: String, start: int, line_num: int, col: int) -> Dictionary:

	var i = start + 3
	var value = '"""'

	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			value += '"""'
			var token = Token.new(TokenType.COMMENT, value, line_num, col)
			return {"token": token, "next_index": i + 3, "next_column": col + value.length(), "multiline": false}
		value += line[i]
		i += 1

	value += "\n"
	var token = Token.new(TokenType.COMMENT, value, line_num, col)
	return {"token": token, "next_index": line.length(), "next_column": col + value.length(), "multiline": true}

func _continue_multiline_comment(line: String, line_num: int) -> Dictionary:
	var i = 0
	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			multiline_buffer += line.substr(0, i) + '"""'
			var token = Token.new(TokenType.COMMENT, multiline_buffer, multiline_start_line, 1)
			tokens.append(token)
			return {"complete": true, "next_index": i + 3, "next_column": i + 4}
		i += 1

	multiline_buffer += line + "\n"
	return {"complete": false, "next_index": line.length(), "next_column": 1}

func _parse_triple_string(line: String, start: int, line_num: int, col: int, quote_chars: String) -> Dictionary:

	var i = start + 3
	var value = quote_chars
	var escaped = false
	
	while i < line.length():
		var current_char = line[i]
		
		if escaped:
			if current_char == "n":
				value += "\\n"
			elif current_char == "t":
				value += "\\t"
			elif current_char == "r":
				value += "\\r"
			elif current_char == "\\":
				value += "\\\\"
			elif current_char == quote_chars[0]:
				value += "\\" + quote_chars[0]
			else:
				value += "\\" + current_char
			escaped = false
			i += 1
		elif current_char == "\\":
			escaped = true
			i += 1
		elif i + 2 < line.length() and line.substr(i, 3) == quote_chars:
			value += quote_chars
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 3, "next_column": col + value.length(), "multiline": false, "error": ""}
		else:
			value += current_char
			i += 1
	
	value += "\n"
	var token = Token.new(TokenType.STRING, value, line_num, col)
	return {"token": token, "next_index": line.length(), "next_column": col + value.length(), "multiline": true, "error": ""}

func _continue_triple_string(line: String, line_num: int) -> Dictionary:
	# Handles both triple-quoted (""" / ''') and Godot 4 multi-line regular (" / ') strings.
	if triple_string_quote.length() == 1:
		var q = triple_string_quote
		var i = 0
		var escaped = false
		while i < line.length():
			var c = line[i]
			if escaped:
				escaped = false
				i += 1
				continue
			if c == "\\":
				escaped = true
				i += 1
				continue
			if c == q:
				multiline_buffer += line.substr(0, i + 1)
				var token = Token.new(TokenType.STRING, multiline_buffer, multiline_start_line, 1)
				tokens.append(token)
				return {"complete": true, "next_index": i + 1, "next_column": i + 2}
			i += 1
		multiline_buffer += line + "\n"
		return {"complete": false, "next_index": line.length(), "next_column": 1}

	var i = 0
	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == triple_string_quote:
			multiline_buffer += line.substr(0, i) + triple_string_quote
			var token = Token.new(TokenType.STRING, multiline_buffer, multiline_start_line, 1)
			tokens.append(token)
			return {"complete": true, "next_index": i + 3, "next_column": i + 4}
		i += 1

	multiline_buffer += line + "\n"
	return {"complete": false, "next_index": line.length(), "next_column": 1}

func _track_brackets(op: String, line_num: int, col: int):
	if op == "(":
		paren_depth += 1
	elif op == ")":
		paren_depth -= 1
		if paren_depth < 0:
			_append_error("TOKEN_UNBALANCED_PAREN", "Line %d:%d: Unbalanced ')'" % [line_num, col])
			paren_depth = 0
	elif op == "[":
		bracket_depth += 1
	elif op == "]":
		bracket_depth -= 1
		if bracket_depth < 0:
			_append_error("TOKEN_UNBALANCED_BRACKET", "Line %d:%d: Unbalanced ']'" % [line_num, col])
			bracket_depth = 0
	elif op == "{":
		brace_depth += 1
	elif op == "}":
		brace_depth -= 1
		if brace_depth < 0:
			_append_error("TOKEN_UNBALANCED_BRACE", "Line %d:%d: Unbalanced '}'" % [line_num, col])
			brace_depth = 0

func _ensure_error_codes():
	if _error_codes == null:
		_error_codes = load(SRC_ROOT + "/error_codes.gd").new()

func _append_error(code: String, detail: String):
	_ensure_error_codes()
	errors.append(_error_codes.format(code, detail))

