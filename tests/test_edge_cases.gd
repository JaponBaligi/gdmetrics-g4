extends SceneTree
const FIXTURE_DIR = "res://tests/fixtures/edge_cases/"
func _init():
	var adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	var cm = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	cm.load_config("res://complexity_config.json")
	var cfg = cm.get_config()
	var dir = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		print("FAIL: cannot open ", FIXTURE_DIR)
		quit(1)
		return
	var passed = 0
	var failed = 0
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			var gd_path = FIXTURE_DIR + name
			var exp_path = FIXTURE_DIR + name.replace(".gd", ".expected.json")
			if _check_one(cfg, adapter, gd_path, exp_path):
				passed += 1
			else:
				failed += 1
		name = dir.get_next()
	print("EDGE_CASES Results: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check_one(cfg, adapter, gd_path: String, exp_path: String) -> bool:
	var expected = {}
	if FileAccess.file_exists(exp_path):
		var txt = FileAccess.get_file_as_string(exp_path)
		var parsed = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			expected = parsed
	var tokenizer = load("res://addons/gdscript_complexity/src/tokenizer.gd").new()
	var tokens = tokenizer.tokenize_file(gd_path)
	var terr = tokenizer.get_errors()
	var detector = load("res://addons/gdscript_complexity/src/control_flow_detector.gd").new()
	var nodes = detector.detect_control_flow(tokens, adapter)
	var funcs = load("res://addons/gdscript_complexity/src/function_detector.gd").new().detect_functions(tokens)
	var count_logical = cfg.cc_config.get("count_logical_operators", true)
	var cc = 0
	var cog = 0
	if tokens.size() > 0:
		cc = load("res://addons/gdscript_complexity/src/cc_calculator.gd").new().calculate_cc(nodes, count_logical)
		cog = load("res://addons/gdscript_complexity/src/cog_complexity_calculator.gd").new().calculate_cog(nodes, funcs).total_cog
	var arms = 0
	for n in nodes:
		if n.type == "case":
			arms += 1
	if expected.has("tokenizer_errors") and terr.size() != int(expected["tokenizer_errors"]):
		print("FAIL %s tokenizer_errors got=%d want=%s" % [gd_path, terr.size(), expected["tokenizer_errors"]])
		return false
	if expected.has("tokenizer_errors_min") and terr.size() < int(expected["tokenizer_errors_min"]):
		print("FAIL %s tokenizer_errors_min got=%d" % [gd_path, terr.size()])
		return false
	if expected.has("cc") and cc != int(expected["cc"]):
		print("FAIL %s cc got=%d want=%s" % [gd_path, cc, expected["cc"]])
		return false
	if expected.has("cc_min") and cc < int(expected["cc_min"]):
		print("FAIL %s cc_min got=%d" % [gd_path, cc])
		return false
	if expected.has("match_arms") and arms != int(expected["match_arms"]):
		print("FAIL %s match_arms got=%d want=%s" % [gd_path, arms, expected["match_arms"]])
		return false
	print("PASS ", gd_path.get_file(), " cc=", cc, " cog=", cog, " arms=", arms, " errs=", terr.size())
	return true
