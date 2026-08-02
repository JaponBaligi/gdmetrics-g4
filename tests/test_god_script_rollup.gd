extends SceneTree

# Smoke: god-script rollup + churn load without parse errors.

func _init():
	var ok = true
	var batch = load("res://addons/gdscript_complexity/src/batch_analyzer.gd")
	var rollup = load("res://addons/gdscript_complexity/src/core/god_script_rollup.gd").new()
	var churn = load("res://addons/gdscript_complexity/src/core/churn_hotspots.gd").new()
	var cfg_mgr = load("res://addons/gdscript_complexity/src/config_manager.gd").new()
	var config = cfg_mgr.get_config()

	var project = batch.ProjectResult.new()
	var fr = batch.FileResult.new()
	fr.success = true
	fr.file_path = "res://fake/god_file.gd"
	fr.cc = 40
	fr.cog = 50
	fr.loc_code = 400
	fr.functions = []
	fr.per_function_cc = {}
	fr.per_function_cog = {}
	fr.per_function_directives = {}
	project.file_results = [fr]

	var gods = rollup.build(project, config, 5)
	if gods.size() != 1:
		print("FAIL: expected 1 god-script, got %d" % gods.size())
		ok = false
	else:
		print("OK god-script: %s label=%s" % [gods[0].get("script_path"), gods[0].get("label")])

	var hot = churn.enrich(gods, "res://", config, 5)
	print("OK churn enrich returned %d (0 is fine without matching git paths)" % hot.size())

	if ok:
		print("PASS test_god_script_rollup")
		quit(0)
	else:
		print("FAIL test_god_script_rollup")
		quit(1)
