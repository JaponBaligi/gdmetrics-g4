# Host CLI: analyze an external Godot 4 project by absolute filesystem path.
# Usage: godot4 --path D:/gdmetrics-g4 --headless -s tests/analyze_external.gd -- D:/path/to/project
extends SceneTree

func _init():
	var root = ""
	# Godot 4: args after `--` live in get_cmdline_user_args()
	var user_args = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		root = str(user_args[0]).replace("\\", "/")
	if root == "":
		var args = OS.get_cmdline_args()
		var dash = args.find("--")
		if dash >= 0 and dash + 1 < args.size():
			root = str(args[dash + 1]).replace("\\", "/")
		elif args.size() > 0:
			# Fallback: last arg that looks like an absolute path
			for i in range(args.size() - 1, -1, -1):
				var a = str(args[i]).replace("\\", "/")
				if a.begins_with("/") or (a.length() >= 3 and a[1] == ":"):
					if a.ends_with(".gd") or a.find("analyze_external") >= 0:
						continue
					root = a
					break
	if root == "":
		print("Usage: godot4 --path <gdmetrics-g4> --headless -s tests/analyze_external.gd -- <project_dir>")
		print("DEBUG cmdline=", OS.get_cmdline_args(), " user=", OS.get_cmdline_user_args())
		quit(1)
		return

	var adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	var cm = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	cm.load_config("res://complexity_config.json")
	var cfg = cm.get_config()
	if not ("res://addons/gdscript_complexity/**" in cfg.exclude_patterns):
		cfg.exclude_patterns.append("res://addons/gdscript_complexity/**")

	var ba = load("res://addons/gdscript_complexity/src/batch_analyzer.gd").new()
	ba.version_adapter = adapter
	var res = ba.analyze_project(root, cfg, adapter)

	var ok = 0
	var fail = 0
	var token_errs = 0
	var codes = {}
	for fr in res.file_results:
		if fr.success:
			ok += 1
		else:
			fail += 1
		token_errs += fr.errors.size()
		for e in fr.errors:
			var s = str(e)
			var code = s
			if s.begins_with("[") and s.find("]") > 0:
				code = s.substr(1, s.find("]") - 1)
			if not codes.has(code):
				codes[code] = 0
			codes[code] += 1

	print("CLI_RESULT root=%s files=%d ok=%d fail=%d cc=%d cog=%d errs=%d" % [
		root, res.total_files, ok, fail, res.total_cc, res.total_cog, token_errs
	])
	if codes.size() > 0:
		print("ERR_CODES ", codes)
	quit(0 if res.total_files > 0 and ok > 0 else 1)
