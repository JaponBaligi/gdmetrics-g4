extends SceneTree

func _init():
	var path = "res://tests/fixtures/edge_cases/directive_ignore_pin.gd"
	var tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	var tokens = tokenizer.tokenize_file(path)
	var funcs = load("res://addons/gdscript_complexity/src/core/function_detector.gd").new().detect_functions(tokens)
	var scanner = load("res://addons/gdscript_complexity/src/core/directive_scanner.gd").new()
	var dirs = scanner.apply_to_functions(tokens, funcs)
	var failed = 0
	if not dirs.get("noisy_but_ok", {}).get("ignored", false):
		print("FAIL noisy_but_ok should be ignored")
		failed += 1
	if dirs.get("watch_me", {}).get("ignored", false):
		print("FAIL watch_me should not be ignored")
		failed += 1
	if not dirs.get("watch_me", {}).get("pinned", false):
		print("FAIL watch_me should be pinned")
		failed += 1
	if dirs.get("normal_complex", {}).get("ignored", false):
		print("FAIL normal_complex should not be ignored")
		failed += 1
	if failed == 0:
		print("PASS directive ignore/pin")
	quit(0 if failed == 0 else 1)
