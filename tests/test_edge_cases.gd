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
	var detector = load("res://addons/gdscript_complexity/src/core/control_flow_detector.gd").new()
	var nodes = detector.detect_control_flow(tokens, adapter)
	var funcs = load("res://addons/gdscript_complexity/src/core/function_detector.gd").new().detect_functions(tokens)
	var count_logical = cfg.cc_config.get("count_logical_operators", true)
	var cc = 0
	var cog = 0
	if tokens.size() > 0:
		cc = load("res://addons/gdscript_complexity/src/core/cc_calculator.gd").new().calculate_cc(nodes, count_logical)
		cog = load("res://addons/gdscript_complexity/src/core/cog_complexity_calculator.gd").new().calculate_cog(nodes, funcs).total_cog
	var arms = 0
	var lambdas = 0
	var has_guard = false
	for n in nodes:
		if n.type == "case":
			arms += 1
			if n.case_has_guard:
				has_guard = true
		elif n.type == "lambda":
			lambdas += 1

	var static_funcs = 0
	var ret_type = ""
	for fi in funcs:
		if fi.type == "static_func":
			static_funcs += 1
		if fi.return_type != "":
			ret_type = fi.return_type

	var classes = load("res://addons/gdscript_complexity/src/core/class_detector.gd").new().detect_classes(tokens)
	var extends_val = ""
	for c in classes:
		if c.extends_class != "":
			extends_val = c.extends_class

	if expected.has("tokenizer_errors") and terr.size() != int(expected["tokenizer_errors"]):
		print("FAIL %s tokenizer_errors got=%d want=%s" % [gd_path, terr.size(), expected["tokenizer_errors"]])
		return false
	if expected.has("tokenizer_errors_min") and terr.size() < int(expected["tokenizer_errors_min"]):
		print("FAIL %s tokenizer_errors_min got=%d" % [gd_path, terr.size()])
		return false
	if expected.has("error_contains"):
		var blob = str(terr)
		if blob.find(str(expected["error_contains"])) < 0:
			print("FAIL %s missing error %s in %s" % [gd_path, expected["error_contains"], blob])
			return false
	if expected.has("cc") and cc != int(expected["cc"]):
		print("FAIL %s cc got=%d want=%s" % [gd_path, cc, expected["cc"]])
		return false
	if expected.has("cc_min") and cc < int(expected["cc_min"]):
		print("FAIL %s cc_min got=%d" % [gd_path, cc])
		return false
	if expected.has("cog") and cog != int(expected["cog"]):
		print("FAIL %s cog got=%d want=%s" % [gd_path, cog, expected["cog"]])
		return false
	if expected.has("cog_min") and cog < int(expected["cog_min"]):
		print("FAIL %s cog_min got=%d" % [gd_path, cog])
		return false
	if expected.has("match_arms") and arms != int(expected["match_arms"]):
		print("FAIL %s match_arms got=%d want=%s" % [gd_path, arms, expected["match_arms"]])
		return false
	if expected.has("lambda_count") and lambdas != int(expected["lambda_count"]):
		print("FAIL %s lambda_count got=%d want=%s" % [gd_path, lambdas, expected["lambda_count"]])
		return false
	if expected.has("lambda_count_min") and lambdas < int(expected["lambda_count_min"]):
		print("FAIL %s lambda_count_min got=%d" % [gd_path, lambdas])
		return false
	if expected.has("has_guard") and has_guard != bool(expected["has_guard"]):
		print("FAIL %s has_guard got=%s want=%s" % [gd_path, has_guard, expected["has_guard"]])
		return false
	if expected.has("static_funcs") and static_funcs != int(expected["static_funcs"]):
		print("FAIL %s static_funcs got=%d" % [gd_path, static_funcs])
		return false
	if expected.has("return_type") and ret_type != str(expected["return_type"]):
		print("FAIL %s return_type got=%s want=%s" % [gd_path, ret_type, expected["return_type"]])
		return false
	if expected.has("extends") and extends_val != str(expected["extends"]):
		print("FAIL %s extends got=%s want=%s" % [gd_path, extends_val, expected["extends"]])
		return false

	print("PASS ", gd_path.get_file(), " cc=", cc, " cog=", cog, " arms=", arms, " lambdas=", lambdas, " errs=", terr.size())
	return true
