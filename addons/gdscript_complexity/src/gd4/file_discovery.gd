extends Object

# File discovery for Godot 4.x (DirAccess, path_join)

var _pattern_cache: Dictionary = {}

func find_files(root_path: String, include_patterns: Array, exclude_patterns: Array) -> Array:
	var files: Array = []
	root_path = _sanitize_path(root_path)
	var dir = DirAccess.open(root_path)
	if dir == null:
		return files
	_find_files_recursive(root_path, root_path, include_patterns, exclude_patterns, files)
	return files

func _sanitize_path(path: String) -> String:
	if path.length() == 0:
		return "."
	var sanitized = path.replace("\\", "/")
	while sanitized.find("../") >= 0:
		sanitized = sanitized.replace("../", "")
	if not sanitized.begins_with("res://"):
		while sanitized.begins_with("/"):
			sanitized = sanitized.substr(1)
	return sanitized

func _find_files_recursive(root_path: String, current_path: String, include_patterns: Array, exclude_patterns: Array, files: Array):
	var dir = DirAccess.open(current_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.find("..") >= 0 or file_name.find("/") >= 0 or file_name.find("\\") >= 0:
			file_name = dir.get_next()
			continue
		var full_path = current_path.path_join(file_name)
		full_path = _sanitize_path(full_path)
		if dir.current_is_dir():
			_find_files_recursive(root_path, full_path, include_patterns, exclude_patterns, files)
		else:
			if file_name.ends_with(".gd"):
				var relative_path = _make_relative(root_path, full_path)
				if _matches_patterns(relative_path, include_patterns, exclude_patterns):
					files.append(full_path)
		file_name = dir.get_next()

func _make_relative(root_path: String, full_path: String) -> String:
	if full_path.begins_with(root_path):
		var relative = full_path.substr(root_path.length())
		if relative.begins_with("/") or relative.begins_with("\\"):
			relative = relative.substr(1)
		return "res://" + relative.replace("\\", "/")
	return full_path

func _matches_patterns(file_path: String, include_patterns: Array, exclude_patterns: Array) -> bool:
	if include_patterns.size() == 0:
		return false
	var matches_include = false
	for pattern in include_patterns:
		if _match_pattern(file_path, pattern):
			matches_include = true
			break
	if not matches_include:
		return false
	for pattern in exclude_patterns:
		if _match_pattern(file_path, pattern):
			return false
	return true

func _match_pattern(file_path: String, pattern: String) -> bool:
	if pattern == "":
		return false
	var normalized_path = file_path.replace("\\", "/")
	var normalized_pattern = pattern.replace("\\", "/")
	if normalized_pattern == normalized_path:
		return true

	# Bare file names (e.g. "player.gd") match by base name anywhere in the tree
	if normalized_pattern.find("/") < 0 and normalized_pattern.ends_with(".gd") and normalized_pattern.find("*") < 0:
		return normalized_path.ends_with("/" + normalized_pattern) or normalized_path == normalized_pattern

	var regex = _get_pattern_regex(normalized_pattern)
	if regex == null:
		return false
	return regex.search(normalized_path) != null

func _get_pattern_regex(pattern: String):
	if _pattern_cache.has(pattern):
		return _pattern_cache[pattern]
	var regex = RegEx.new()
	if regex.compile(_glob_to_regex(pattern)) != OK:
		_pattern_cache[pattern] = null
		return null
	_pattern_cache[pattern] = regex
	return regex

func _glob_to_regex(pattern: String) -> String:
	const SPECIAL = ".^$+(){}[]|\\"
	var out = "^"
	var i = 0
	while i < pattern.length():
		var c = pattern[i]
		if c == "*":
			if i + 1 < pattern.length() and pattern[i + 1] == "*":
				# "**/" spans zero or more directories, bare "**" spans anything
				if i + 2 < pattern.length() and pattern[i + 2] == "/":
					out += "(?:.*/)?"
					i += 3
					continue
				out += ".*"
				i += 2
				continue
			out += "[^/]*"
		elif c == "?":
			out += "[^/]"
		elif SPECIAL.find(c) >= 0:
			out += "\\" + c
		else:
			out += c
		i += 1
	return out + "$"
