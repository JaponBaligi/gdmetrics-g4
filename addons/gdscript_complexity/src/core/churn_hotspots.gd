extends Object

# Optional git churn overlay for scary files. Quietly returns [] if git unavailable.
# Dual Godot 3/4 — uses dynamic calls so each engine only hits a valid OS.execute shape.
# Never blocks forever: requires a local .git dir, and always passes --no-pager.

func enrich(god_scripts: Array, project_path: String, config, limit: int = 5) -> Array:
	var mode = "auto"
	if config != null and config.report_config.has("churn_hotspots"):
		mode = str(config.report_config.get("churn_hotspots", "auto")).to_lower()
	if mode == "off" or mode == "false" or mode == "0":
		return []
	if god_scripts.size() == 0:
		return []

	var root = _normalize_project_path(project_path)
	if root == "":
		return []
	# Cheap gate: no .git folder ⇒ skip OS.execute entirely (avoids PATH/hangs).
	if not _has_git_dir(root):
		return []
	if not _git_available(root):
		return []

	var since = "90 days ago"
	if config != null and config.report_config.has("churn_since"):
		var s = str(config.report_config.get("churn_since", ""))
		if s != "":
			since = s

	var churn_map = _git_churn_map(root, since)
	if churn_map.size() == 0:
		return []

	var hot = []
	for entry in god_scripts:
		var path = str(entry.get("script_path", ""))
		var key = _path_key(path)
		var lines = int(churn_map.get(key, 0))
		if lines <= 0:
			lines = int(churn_map.get(path.get_file().to_lower(), 0))
		if lines <= 0:
			continue
		var row = entry.duplicate(true)
		row["churn_lines"] = lines
		row["reason_text"] = "Scary + recently changed (%d lines touched)" % lines
		row["label"] = "Hot"
		hot.append(row)

	_sort_by_churn(hot)
	if hot.size() > limit:
		var trimmed = []
		for i in range(limit):
			trimmed.append(hot[i])
		return trimmed
	return hot

func _normalize_project_path(project_path: String) -> String:
	var p = project_path.strip_edges()
	if p == "":
		p = "res://"
	if p.begins_with("res://"):
		p = ProjectSettings.globalize_path(p)
	p = p.replace("\\", "/")
	while p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p

func _has_git_dir(root: String) -> bool:
	# Prefer .git/HEAD (file) — avoids Directory/DirAccess (dual-parse landmines).
	# Worktrees where .git is a file are also accepted via the .git path check.
	if _file_exists(root + "/.git/HEAD"):
		return true
	return _file_exists(root + "/.git")

func _file_exists(path: String) -> bool:
	# Never name FileAccess/File as identifiers — ClassDB only for G3/G4 parse safety.
	if ClassDB.class_exists("FileAccess"):
		return bool(ClassDB.class_call_static("FileAccess", "file_exists", path))
	if not ClassDB.class_exists("File"):
		return false
	var f = ClassDB.instance("File")
	if f == null:
		return false
	var ok = bool(f.call("file_exists", path))
	f = null
	return ok

func _git_run(root: String, git_args: Array) -> Array:
	# Returns [exit_code:int, output_lines:Array]
	# Always use OS.call — Godot 3/4 have different execute() signatures, and each
	# engine parse-checks both branches of a direct OS.execute(...) call.
	var output = []
	var args = ["--no-pager", "-C", root]
	for a in git_args:
		args.append(a)
	var major = int(Engine.get_version_info().get("major", 4))
	var code = 1
	if major >= 4:
		# Godot 4: execute(path, arguments, output, read_stderr, open_console)
		code = int(OS.call("execute", "git", args, output, false, false))
	else:
		# Godot 3: execute(path, arguments, blocking, output, read_stderr)
		code = int(OS.call("execute", "git", args, true, output, false))
	return [code, output]

func _git_available(root: String) -> bool:
	var result = _git_run(root, ["rev-parse", "--is-inside-work-tree"])
	if int(result[0]) != 0:
		return false
	var blob = ""
	for line in result[1]:
		blob += str(line)
	return blob.find("true") >= 0

func _git_churn_map(root: String, since: String) -> Dictionary:
	var result = _git_run(root, ["log", "--since=" + since, "--pretty=format:", "--numstat", "--", "*.gd"])
	if int(result[0]) != 0:
		return {}
	var map = {}
	for line in result[1]:
		var text = str(line).strip_edges()
		if text == "":
			continue
		var parts = text.split("\t")
		if parts.size() < 3:
			continue
		var added = 0
		var deleted = 0
		if _is_int_str(str(parts[0])):
			added = int(parts[0])
		if _is_int_str(str(parts[1])):
			deleted = int(parts[1])
		var path = str(parts[2]).replace("\\", "/")
		var key = _path_key(path)
		var total = added + deleted
		map[key] = int(map.get(key, 0)) + total
		var fname = path.get_file().to_lower()
		map[fname] = int(map.get(fname, 0)) + total
	return map

func _is_int_str(s: String) -> bool:
	if s == "" or s == "-":
		return false
	var i = 0
	while i < s.length():
		var c = s.substr(i, 1)
		if c < "0" or c > "9":
			return false
		i += 1
	return true

func _path_key(path: String) -> String:
	var p = path.replace("\\", "/").to_lower()
	if p.begins_with("res://"):
		p = p.substr(6)
	return p

func _sort_by_churn(entries: Array) -> void:
	for i in range(1, entries.size()):
		var key_item = entries[i]
		var j = i - 1
		while j >= 0 and int(key_item.get("churn_lines", 0)) > int(entries[j].get("churn_lines", 0)):
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = key_item
