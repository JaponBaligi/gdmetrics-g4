extends Object

# Parse `# gdmetrics:…` comments and stamp FunctionInfo flags.
# Dual Godot 3/4 compatible (synced via sync_core.ps1).
#
# Supported (line above `func`, or trailing on the func line):
#   # gdmetrics:ignore       — skip threshold gate + Top fixes
#   # gdmetrics:ignore-next  — same as ignore for the next function
#   # gdmetrics:pin          — always list in Top fixes (watch list)

const PREFIX := "gdmetrics:"

func apply_to_functions(tokens: Array, functions: Array) -> Dictionary:
	# Returns name -> { "ignored": bool, "pinned": bool }
	var by_name = {}
	if tokens.size() == 0 or functions.size() == 0:
		return by_name

	var TokenType = _token_type()
	var line_dirs = {}
	for token in tokens:
		if token.type != TokenType.COMMENT:
			continue
		var parsed = _parse_comment(str(token.value))
		if parsed.size() == 0:
			continue
		var line = int(token.line)
		if not line_dirs.has(line):
			line_dirs[line] = {"ignore": false, "pin": false, "ignore_next": false}
		var slot = line_dirs[line]
		if parsed.get("ignore", false):
			slot["ignore"] = true
		if parsed.get("pin", false):
			slot["pin"] = true
		if parsed.get("ignore_next", false):
			slot["ignore_next"] = true

	for func_info in functions:
		var ignored = false
		var pinned = false
		var start = int(_prop(func_info, "start_line", 1))
		if line_dirs.has(start):
			var here = line_dirs[start]
			if here.get("ignore", false) or here.get("ignore_next", false):
				ignored = true
			if here.get("pin", false):
				pinned = true
		var prev = start - 1
		if prev >= 1 and line_dirs.has(prev):
			var above = line_dirs[prev]
			if above.get("ignore", false) or above.get("ignore_next", false):
				ignored = true
			if above.get("pin", false):
				pinned = true
		_set_flag(func_info, "ignored", ignored)
		_set_flag(func_info, "pinned", pinned)
		var fname = str(_prop(func_info, "name", ""))
		by_name[fname] = {"ignored": ignored, "pinned": pinned}
	return by_name

func is_ignored(func_info, directives: Dictionary = {}) -> bool:
	if _flag(func_info, "ignored"):
		return true
	var name = str(_prop(func_info, "name", ""))
	if name != "" and directives.has(name):
		return bool(directives[name].get("ignored", false))
	return false

func is_pinned(func_info, directives: Dictionary = {}) -> bool:
	if _flag(func_info, "pinned"):
		return true
	var name = str(_prop(func_info, "name", ""))
	if name != "" and directives.has(name):
		return bool(directives[name].get("pinned", false))
	return false

func _parse_comment(text: String) -> Dictionary:
	var body = text.strip_edges()
	if body.begins_with("#"):
		body = body.substr(1).strip_edges()
	var lower = body.to_lower()
	var idx = lower.find(PREFIX)
	if idx < 0:
		return {}
	var rest = lower.substr(idx + PREFIX.length()).strip_edges()
	var chunk = rest
	var space = rest.find(" ")
	if space >= 0:
		chunk = rest.substr(0, space)
	var out = {"ignore": false, "pin": false, "ignore_next": false}
	var parts = chunk.split(",")
	for p in parts:
		var key = str(p).strip_edges()
		if key == "ignore" or key == "skip":
			out["ignore"] = true
		elif key == "ignore-next" or key == "ignore_next":
			out["ignore_next"] = true
		elif key == "pin" or key == "watch":
			out["pin"] = true
	if out["ignore"] or out["pin"] or out["ignore_next"]:
		return out
	return {}

func _prop(obj, key: String, default_value):
	if obj == null:
		return default_value
	if typeof(obj) == TYPE_DICTIONARY:
		return obj.get(key, default_value)
	return obj.get(key)

func _flag(obj, key: String) -> bool:
	if obj == null:
		return false
	if typeof(obj) == TYPE_DICTIONARY:
		return bool(obj.get(key, false))
	if obj.get(key) == null:
		return false
	return bool(obj.get(key))

func _set_flag(obj, key: String, value: bool) -> void:
	if obj == null:
		return
	if typeof(obj) == TYPE_DICTIONARY:
		obj[key] = value
		return
	obj.set(key, value)

func _token_type():
	var major = Engine.get_version_info().get("major", 0)
	var path = "res://addons/gdscript_complexity/src/tokenizer.gd"
	if major < 4:
		path = "res://addons/gdscript_complexity/src/gd3/tokenizer.gd"
	return load(path).TokenType
